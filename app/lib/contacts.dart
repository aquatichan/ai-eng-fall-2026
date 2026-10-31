import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ContactsPermissionDenied implements Exception {
  ContactsPermissionDenied({required this.permanently});

  /// True when asking again won't show a prompt, so the user has to go to Settings.
  final bool permanently;

  @override
  String toString() => 'AutoContact needs Contacts access for this.';
}

class SyncResult {
  SyncResult({required this.added, required this.updated, required this.unchanged});

  final int added;

  /// Already in Contacts, and got new numbers, emails or details merged in.
  final int updated;

  /// Already in Contacts with nothing new.
  final int unchanged;

  String get summary {
    final parts = [
      if (added > 0) 'Added $added',
      if (updated > 0) 'Updated $updated',
      if (unchanged > 0) '$unchanged already up to date',
    ];
    return parts.isEmpty ? 'Nothing to do' : parts.join(' · ');
  }
}

const _props = {
  ContactProperty.name,
  ContactProperty.phone,
  ContactProperty.email,
  ContactProperty.organization,
  ContactProperty.website,
  ContactProperty.address,
  ContactProperty.event,
};

/// Adds members who aren't in Contacts yet and merges new details into those
/// who are. Never deletes anything from an existing contact.
///
/// A member is matched to a contact by the link saved the last time we synced
/// them, or else by a shared phone number or email.
Future<SyncResult> syncToContacts(List<Member> members) async {
  await _requireAccess();
  final existing = await FlutterContacts.getAll(properties: _props);
  final byId = {for (final c in existing) c.id: c};
  final links = await _ContactLinks.load();

  final toCreate = <Member>[];
  final toUpdate = <Contact>[];
  var unchanged = 0;
  for (final m in members) {
    final match = byId[links[m.userId]] ?? findMatch(m.card, existing);
    if (match == null) {
      toCreate.add(m);
      continue;
    }
    links[m.userId] = match.id!;
    final merged = mergeInto(match, m.card);
    merged == null ? unchanged++ : toUpdate.add(merged);
  }

  if (toUpdate.isNotEmpty) await FlutterContacts.updateAll(toUpdate);
  if (toCreate.isNotEmpty) {
    final ids = await FlutterContacts.createAll([for (final m in toCreate) toDeviceContact(m.card)]);
    for (final (i, id) in ids.indexed) {
      links[toCreate[i].userId] = id;
    }
  }
  await _ContactLinks.save(links);
  return SyncResult(added: toCreate.length, updated: toUpdate.length, unchanged: unchanged);
}

/// Opens the system contact picker so you can choose your own card, and
/// remembers it for [reloadMyCard].
Future<ContactCard?> pickMyCard() async {
  // Android only returns the picked contact's details with READ_CONTACTS.
  if (Platform.isAndroid) await _requireAccess();
  final contact = await FlutterContacts.native.showPicker(properties: _props);
  if (contact == null) return null;
  final prefs = await SharedPreferences.getInstance();
  if (contact.id != null) await prefs.setString(_myContactKey, contact.id!);
  return cardFromContact(contact);
}

/// Re-reads the contact you picked with [pickMyCard], so edits you made in
/// the Contacts app flow back into AutoContact. Null if none was picked or it
/// was deleted.
Future<ContactCard?> reloadMyCard() async {
  final id = (await SharedPreferences.getInstance()).getString(_myContactKey);
  if (id == null) return null;
  await _requireAccess();
  final contact = await FlutterContacts.get(id, properties: _props);
  return contact == null ? null : cardFromContact(contact);
}

Future<bool> hasLinkedMyCard() async =>
    (await SharedPreferences.getInstance()).getString(_myContactKey) != null;

Future<void> openContactsSettings() => FlutterContacts.permissions.openSettings();

/// The card as a vCard file, with every field and label.
String cardVCard(ContactCard card) => FlutterContacts.vCard.export(toDeviceContact(card));

/// The smallest vCard that still carries everything, for a QR code: fewer
/// bytes means bigger modules, which cameras read more reliably off a screen.
/// Scanning it with the iPhone or Android camera offers "Add to Contacts".
String qrVCard(ContactCard card) {
  String esc(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll(',', r'\,').replaceAll(';', r'\;').replaceAll('\n', r'\n');
  final b = card.birthday;
  return [
    'BEGIN:VCARD',
    'VERSION:3.0',
    'N:${esc(card.lastName ?? '')};${esc(card.firstName)}',
    'FN:${esc(card.fullName)}',
    if (_present(card.company)) 'ORG:${esc(card.company!)}',
    if (_present(card.jobTitle)) 'TITLE:${esc(card.jobTitle!)}',
    for (final p in card.phones) 'TEL;TYPE=${_vCardPhoneType(p.label)}:${p.value}',
    for (final e in card.emails) 'EMAIL;TYPE=${e.label == 'work' ? 'WORK' : 'HOME'}:${e.value}',
    if (_present(card.website)) 'URL:${esc(card.website!)}',
    if (_present(card.address)) 'ADR:;;${esc(card.address!)};;;;',
    if (b != null) 'BDAY:${b.year.toString().padLeft(4, '0')}${b.month.toString().padLeft(2, '0')}${b.day.toString().padLeft(2, '0')}',
    'END:VCARD',
  ].join('\r\n');
}

String _vCardPhoneType(String label) => switch (label) {
      'iphone' => 'IPHONE',
      'home' => 'HOME',
      'work' => 'WORK',
      'main' => 'MAIN',
      'pager' => 'PAGER',
      'other' => 'VOICE',
      _ => 'CELL',
    };

/// Shares the roster as one .vcf file, which any contacts app can import.
/// [origin] anchors the share sheet on iPad.
Future<void> shareRosterVCard(String groupName, List<Member> members, {Rect? origin}) async {
  final vcf = rosterVCard(members);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_fileName(groupName)}.vcf');
  await file.writeAsString(vcf);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/vcard')],
      subject: '$groupName contacts',
      sharePositionOrigin: origin,
    ),
  );
}

String rosterVCard(List<Member> members) =>
    FlutterContacts.vCard.exportAll([for (final m in members) toDeviceContact(m.card)]);

Future<void> _requireAccess() async {
  final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
  // iOS 18 "limited" access still allows creating contacts; we just see fewer existing ones.
  if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
    throw ContactsPermissionDenied(
      permanently: status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted,
    );
  }
}

Contact toDeviceContact(ContactCard card, {bool? android}) {
  final isAndroid = android ?? Platform.isAndroid;
  final b = card.birthday;
  return Contact(
    name: Name(first: card.firstName, last: card.lastName),
    phones: [for (final p in card.phones) Phone(number: p.value, label: Label(_phoneLabel(p.label, isAndroid)))],
    emails: [for (final e in card.emails) Email(address: e.value, label: Label(_emailLabel(e.label, isAndroid)))],
    organizations: [
      if (_present(card.company) || _present(card.jobTitle)) Organization(name: card.company, jobTitle: card.jobTitle),
    ],
    websites: [if (_present(card.website)) Website(url: card.website!)],
    addresses: [if (_present(card.address)) Address(street: card.address)],
    events: [if (b != null) Event(year: b.year, month: b.month, day: b.day, label: const Label(EventLabel.birthday))],
  );
}

/// Your card from a contact in the phone, for onboarding and "update from my card".
ContactCard cardFromContact(Contact c) {
  final names = (c.displayName ?? '').trim().split(RegExp(r'\s+'));
  final first = _present(c.name?.first) ? c.name!.first! : names.first;
  final last = _present(c.name?.first) ? c.name?.last : (names.length > 1 ? names.skip(1).join(' ') : null);
  final org = c.organizations.firstOrNull;
  final address = c.addresses.firstOrNull;
  final birthday = c.events.where((e) => e.label.label == EventLabel.birthday && e.year != null).firstOrNull;
  return ContactCard(
    firstName: first.isEmpty ? 'Me' : first,
    lastName: _present(last) ? last : null,
    phones: [for (final p in c.phones.take(5)) LabeledValue(_cardPhoneLabel(p.label.label), p.number)],
    emails: [for (final e in c.emails.take(5)) LabeledValue(_cardEmailLabel(e.label.label), e.address)],
    company: org?.name,
    jobTitle: org?.jobTitle,
    website: c.websites.firstOrNull?.url,
    address: address == null ? null : _addressText(address),
    birthday: birthday == null ? null : DateTime(birthday.year!, birthday.month, birthday.day),
  );
}

/// The contact that shares a phone number or email with [card], if any.
Contact? findMatch(ContactCard card, List<Contact> existing) {
  final keys = _keys(card.phones.map((p) => p.value), card.emails.map((e) => e.value));
  if (keys.isEmpty) return null;
  for (final c in existing) {
    if (_keys(c.phones.map((p) => p.number), c.emails.map((e) => e.address)).intersection(keys).isNotEmpty) {
      return c;
    }
  }
  return null;
}

/// [contact] with anything new from [card] merged in, or null if it already
/// has everything. Adds numbers, emails, website, address and birthday it's
/// missing and takes the card's company and job title. Never removes anything
/// and leaves the name alone, in case you renamed them.
Contact? mergeInto(Contact contact, ContactCard card, {bool? android}) {
  final fresh = toDeviceContact(card, android: android);
  final phoneKeys = _keys(contact.phones.map((p) => p.number), const []);
  final emailKeys = _keys(const [], contact.emails.map((e) => e.address));
  final newPhones = fresh.phones.where((p) => _keys([p.number], const []).intersection(phoneKeys).isEmpty).toList();
  final newEmails = fresh.emails.where((e) => !emailKeys.contains('mailto:${e.address.trim().toLowerCase()}')).toList();
  final newWebsites = fresh.websites.where((w) => !contact.websites.any((x) => x.url == w.url)).toList();
  final newAddresses =
      fresh.addresses.where((a) => !contact.addresses.any((x) => _addressText(x) == a.street)).toList();
  final newEvents = contact.events.any((e) => e.label.label == EventLabel.birthday) ? <Event>[] : fresh.events;

  final cardOrg = fresh.organizations.firstOrNull;
  final current = contact.organizations.firstOrNull;
  final orgChanged = cardOrg != null && (cardOrg.name != current?.name || cardOrg.jobTitle != current?.jobTitle);

  if (newPhones.isEmpty &&
      newEmails.isEmpty &&
      newWebsites.isEmpty &&
      newAddresses.isEmpty &&
      newEvents.isEmpty &&
      !orgChanged) {
    return null;
  }
  return contact.copyWith(
    phones: [...contact.phones, ...newPhones],
    emails: [...contact.emails, ...newEmails],
    websites: [...contact.websites, ...newWebsites],
    addresses: [...contact.addresses, ...newAddresses],
    events: [...contact.events, ...newEvents],
    organizations: orgChanged ? [cardOrg, ...contact.organizations.skip(1)] : contact.organizations,
  );
}

PhoneLabel _phoneLabel(String label, bool android) => switch (label) {
      'mobile' => PhoneLabel.mobile,
      // Android has no "iPhone" label.
      'iphone' => android ? PhoneLabel.mobile : PhoneLabel.iPhone,
      'home' => PhoneLabel.home,
      'work' => PhoneLabel.work,
      'main' => PhoneLabel.main,
      'pager' => PhoneLabel.pager,
      _ => PhoneLabel.other,
    };

EmailLabel _emailLabel(String label, bool android) => switch (label) {
      'home' => EmailLabel.home,
      'work' => EmailLabel.work,
      'school' => EmailLabel.school,
      'icloud' => android ? EmailLabel.other : EmailLabel.iCloud,
      _ => EmailLabel.other,
    };

String _cardPhoneLabel(PhoneLabel l) => switch (l) {
      PhoneLabel.mobile || PhoneLabel.workMobile => 'mobile',
      PhoneLabel.iPhone => 'iphone',
      PhoneLabel.home => 'home',
      PhoneLabel.work => 'work',
      PhoneLabel.main || PhoneLabel.companyMain => 'main',
      PhoneLabel.pager || PhoneLabel.workPager => 'pager',
      _ => 'other',
    };

String _cardEmailLabel(EmailLabel l) => switch (l) {
      EmailLabel.home => 'home',
      EmailLabel.work => 'work',
      EmailLabel.school => 'school',
      EmailLabel.iCloud => 'icloud',
      _ => 'other',
    };

String _addressText(Address a) {
  if (_present(a.formatted)) return a.formatted!;
  return [a.street, a.city, a.state, a.postalCode, a.country].where(_present).join(', ');
}

bool _present(String? s) => s != null && s.trim().isNotEmpty;

/// Identifies a person across address books: the last 10 digits of a phone
/// number (so "+1 (555) 010-2030" matches "5550102030") and the lowercased email.
Set<String> _keys(Iterable<String> phones, Iterable<String> emails) => {
      for (final p in phones)
        if (p.replaceAll(RegExp(r'\D'), '') case final digits when digits.length >= 7)
          'tel:${digits.length > 10 ? digits.substring(digits.length - 10) : digits}',
      for (final e in emails)
        if (e.trim().isNotEmpty) 'mailto:${e.trim().toLowerCase()}',
    };

String _fileName(String groupName) {
  final cleaned = groupName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  return cleaned.isEmpty ? 'roster' : cleaned;
}

const _myContactKey = 'my_contact_id';

/// Which phone contact each AutoContact user was saved as, so a person who
/// changes both their number and email still updates the same contact.
class _ContactLinks {
  static const _key = 'contact_links';

  static Future<Map<String, String>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null ? {} : Map<String, String>.from(jsonDecode(raw) as Map);
  }

  static Future<void> save(Map<String, String> links) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode(links));
}
