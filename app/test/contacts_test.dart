import 'package:autocontact/contacts.dart';
import 'package:autocontact/models.dart';
import 'package:autocontact/widgets.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

final ana = ContactCard(
  firstName: 'Ana',
  lastName: 'de la Cruz',
  phones: const [LabeledValue('iphone', '+1 (555) 010-2030'), LabeledValue('work', '555 010 9999')],
  emails: const [LabeledValue('icloud', 'ana@crew.co')],
  company: 'Lighting Co',
  jobTitle: 'Gaffer',
  website: 'https://ana.example',
  address: '1 Main St, Springfield',
  birthday: DateTime(1999, 2, 3),
);

void main() {
  group('toDeviceContact', () {
    test('keeps Apple labels on iOS', () {
      final c = toDeviceContact(ana, android: false);
      expect(c.name?.first, 'Ana');
      expect(c.name?.last, 'de la Cruz');
      expect(c.phones.map((p) => p.label.label), [PhoneLabel.iPhone, PhoneLabel.work]);
      expect(c.emails.single.label.label, EmailLabel.iCloud);
      expect(c.organizations.single.jobTitle, 'Gaffer');
      expect(c.websites.single.url, 'https://ana.example');
      expect(c.addresses.single.street, '1 Main St, Springfield');
      expect(c.events.single.label.label, EventLabel.birthday);
    });

    test('maps Apple-only labels to Android ones', () {
      final c = toDeviceContact(ana, android: true);
      expect(c.phones.first.label.label, PhoneLabel.mobile);
      expect(c.emails.single.label.label, EmailLabel.other);
    });

    test('leaves out empty sections', () {
      final c = toDeviceContact(const ContactCard(firstName: 'Bo'), android: false);
      expect([c.phones, c.emails, c.organizations, c.websites, c.addresses, c.events], everyElement(isEmpty));
    });
  });

  test('cardFromContact round-trips through a device contact', () {
    final card = cardFromContact(toDeviceContact(ana, android: false));
    expect(card.toJson(), ana.toJson());
  });

  group('findMatch', () {
    test('matches a number saved in another format', () {
      final saved = Contact(id: 'c1', phones: [Phone(number: '5550102030')]);
      expect(findMatch(ana, [Contact(id: 'c0'), saved])?.id, 'c1');
    });

    test('matches email regardless of case', () {
      expect(findMatch(ana, [Contact(id: 'c1', emails: [Email(address: 'ANA@crew.co')])])?.id, 'c1');
    });

    test('ignores short numbers that would match too much', () {
      const card = ContactCard(firstName: 'Dee', phones: [LabeledValue('mobile', '911')]);
      expect(findMatch(card, [Contact(id: 'c1', phones: [Phone(number: '911')])]), isNull);
    });
  });

  group('mergeInto', () {
    test('adds new details and never removes existing ones', () {
      final existing = Contact(
        id: 'c1',
        name: const Name(first: 'Ana (lighting)'),
        phones: [Phone(number: '5550102030'), Phone(number: '555 777 0000')],
        notes: const [],
        organizations: const [Organization(name: 'Old Co')],
      );
      final merged = mergeInto(existing, ana, android: false)!;
      expect(merged.name?.first, 'Ana (lighting)', reason: 'your own name for them stays');
      expect(merged.phones.map((p) => p.number), ['5550102030', '555 777 0000', '555 010 9999']);
      expect(merged.emails.single.address, 'ana@crew.co');
      expect(merged.organizations.single.name, 'Lighting Co');
      expect(merged.websites, hasLength(1));
      expect(merged.addresses, hasLength(1));
      expect(merged.events, hasLength(1));
    });

    test('returns null when the contact is already up to date', () {
      final upToDate = toDeviceContact(ana, android: false).copyWith(id: 'c1');
      expect(mergeInto(upToDate, ana, android: false), isNull);
    });

    test('keeps an existing birthday', () {
      final existing = Contact(id: 'c1', events: [const Event(month: 5, day: 6, label: Label(EventLabel.birthday))]);
      final merged = mergeInto(existing, ana, android: false)!;
      expect(merged.events.single.month, 5);
    });
  });

  test('SyncResult summary', () {
    expect(SyncResult(added: 2, updated: 1, unchanged: 3).summary, 'Added 2 · Updated 1 · 3 already up to date');
    expect(SyncResult(added: 0, updated: 0, unchanged: 0).summary, 'Nothing to do');
  });

  test('cardVCard is a single card a camera can read', () {
    final vcf = cardVCard(ana);
    expect('BEGIN:VCARD'.allMatches(vcf), hasLength(1));
    expect(vcf, contains('Gaffer'));
    expect(vcf, contains('ana@crew.co'));
  });

  test('qrVCard is compact and escapes special characters', () {
    final vcf = qrVCard(ana.copyWithAddress('1 Main St; Apt 2\nSpringfield, IL'));
    final lines = vcf.split('\r\n');
    expect(lines.first, 'BEGIN:VCARD');
    expect(lines.last, 'END:VCARD');
    expect(lines, contains('N:de la Cruz;Ana'));
    expect(lines, contains('TEL;TYPE=IPHONE:+1 (555) 010-2030'));
    expect(lines, contains(r'ADR:;;1 Main St\; Apt 2\nSpringfield\, IL;;;;'));
    expect(lines, contains('BDAY:19990203'));
    expect(vcf, isNot(contains('PRODID')));
    expect(vcf.length, lessThan(cardVCard(ana).length));
  });

  group('JoinCodeFormatter', () {
    String type(List<String> steps) {
      final f = JoinCodeFormatter();
      var value = TextEditingValue.empty;
      for (final text in steps) {
        value = f.formatEditUpdate(value, TextEditingValue(text: text));
      }
      return value.text;
    }

    test('inserts the hyphen after three characters', () {
      expect(type(['a', 'ab', 'abc']), 'ABC-');
      expect(type(['a', 'ab', 'abc', 'ABC-1', 'ABC-12', 'ABC-123']), 'ABC-123');
    });

    test('backspacing over the hyphen removes the letter before it', () {
      expect(type(['abc', 'ABC']), 'AB');
    });

    test('cleans pasted codes and caps the length', () {
      expect(type(['abc 123']), 'ABC-123');
      expect(type(['abc-1234']), 'ABC-123');
    });
  });
}

extension on ContactCard {
  ContactCard copyWithAddress(String address) => ContactCard(
        firstName: firstName,
        lastName: lastName,
        phones: phones,
        emails: emails,
        company: company,
        jobTitle: jobTitle,
        website: website,
        address: address,
        birthday: birthday,
      );
}
