import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../contacts.dart';
import '../models.dart';
import '../widgets.dart';

/// Edits your contact card. With [onboarding] it's the first screen after
/// sign-in: no back button, and [onSaved] is called instead of popping.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.meId,
    this.initial,
    this.onboarding = false,
    this.onSaved,
  });

  final Api api;

  /// Your user ID, to remember which phone contact is your card.
  final String meId;
  final ContactCard? initial;
  final bool onboarding;
  final ValueChanged<ContactCard>? onSaved;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _Row {
  _Row(this.label, String value) : controller = TextEditingController(text: value);

  String label;
  final TextEditingController controller;
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _company = TextEditingController();
  final _title = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _phones = <_Row>[];
  final _emails = <_Row>[];
  DateTime? _birthday;
  bool _saving = false;
  bool _linkedToContact = false;

  @override
  void initState() {
    super.initState();
    _fill(widget.initial ?? _fromGoogleAccount());
    hasLinkedMyCard(widget.meId).then((linked) {
      if (mounted) setState(() => _linkedToContact = linked);
    });
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _company, _title, _website, _address]) {
      c.dispose();
    }
    for (final r in [..._phones, ..._emails]) {
      r.controller.dispose();
    }
    super.dispose();
  }

  ContactCard _fromGoogleAccount() {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? const {};
    final names = (meta['full_name'] ?? meta['name'] ?? '').toString().trim().split(RegExp(r'\s+'));
    return ContactCard(
      firstName: names.first,
      lastName: names.length > 1 ? names.skip(1).join(' ') : null,
      emails: [if (user?.email != null) LabeledValue('home', user!.email!)],
    );
  }

  void _fill(ContactCard card) {
    _first.text = card.firstName;
    _last.text = card.lastName ?? '';
    _company.text = card.company ?? '';
    _title.text = card.jobTitle ?? '';
    _website.text = card.website ?? '';
    _address.text = card.address ?? '';
    _birthday = card.birthday;
    _phones
      ..clear()
      ..addAll([for (final p in card.phones) _Row(p.label, p.value)]);
    if (_phones.isEmpty) _phones.add(_Row('mobile', ''));
    _emails
      ..clear()
      ..addAll([for (final e in card.emails) _Row(e.label, e.value)]);
    if (_emails.isEmpty) _emails.add(_Row('home', ''));
  }

  ContactCard _read() {
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    List<LabeledValue> rows(List<_Row> rs) => [
          for (final r in rs)
            if (r.controller.text.trim().isNotEmpty) LabeledValue(r.label, r.controller.text.trim()),
        ];
    return ContactCard(
      firstName: _first.text.trim(),
      lastName: opt(_last),
      phones: rows(_phones),
      emails: rows(_emails),
      company: opt(_company),
      jobTitle: opt(_title),
      website: opt(_website),
      address: opt(_address),
      birthday: _birthday,
    );
  }

  Future<void> _importFromContacts({required bool reload}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final card = reload ? await reloadMyCard(widget.meId) : await pickMyCard(widget.meId);
      if (card == null) {
        if (reload) messenger.showSnackBar(const SnackBar(content: Text("Couldn't find your contact card anymore")));
        return;
      }
      setState(() {
        _fill(card);
        _linkedToContact = true;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Filled in from your contact card. Review, then save.')));
    } on ContactsPermissionDenied catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          action: e.permanently ? SnackBarAction(label: 'Settings', onPressed: openContactsSettings) : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not read Contacts: $e')));
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.api.saveProfile(_read());
      if (!mounted) return;
      if (widget.onSaved != null) {
        widget.onSaved!(saved);
      } else {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onboarding ? 'Set up your card' : 'My info'),
        automaticallyImplyLeading: !widget.onboarding,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              widget.onboarding
                  ? "This is the card your crews get when they add you to Contacts. You set it up once and every group uses it."
                  : 'Changes show up in every group you\'re in. Anyone who syncs the group gets them merged into their Contacts.',
              style: muted,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(_linkedToContact ? Icons.sync_rounded : Icons.contact_page_rounded),
              label: Text(_linkedToContact ? 'Update from my contact card' : 'Fill in from my contact card'),
              onPressed: _saving ? null : () => _importFromContacts(reload: _linkedToContact),
            ),
            if (_linkedToContact)
              TextButton(
                onPressed: _saving ? null : () => _importFromContacts(reload: false),
                child: const Text('Use a different contact'),
              ),
            const SizedBox(height: 24),
            const SectionLabel('Name'),
            const SizedBox(height: 8),
            _field(_first, 'First name', Icons.person_rounded,
                capitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'First name is required' : null),
            const SizedBox(height: 12),
            _field(_last, 'Last name', null, capitalization: TextCapitalization.words),
            const SizedBox(height: 24),
            const SectionLabel('Phone'),
            const SizedBox(height: 8),
            ..._rows(_phones, phoneLabels, 'Phone', TextInputType.phone, _validatePhone, () => 'mobile'),
            const SizedBox(height: 24),
            const SectionLabel('Email'),
            const SizedBox(height: 8),
            ..._rows(_emails, emailLabels, 'Email', TextInputType.emailAddress, _validateEmail, () => 'work'),
            const SizedBox(height: 24),
            const SectionLabel('Work'),
            const SizedBox(height: 8),
            _field(_company, 'Company', Icons.business_rounded, capitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            _field(_title, 'Job title', Icons.work_rounded, capitalization: TextCapitalization.words),
            const SizedBox(height: 24),
            const SectionLabel('More'),
            const SizedBox(height: 8),
            _field(_website, 'Website', Icons.link_rounded, keyboard: TextInputType.url),
            const SizedBox(height: 12),
            _field(_address, 'Address', Icons.home_rounded, maxLines: 3, capitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickBirthday,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Birthday',
                  prefixIcon: const Icon(Icons.cake_rounded),
                  suffixIcon: _birthday == null
                      ? null
                      : IconButton(
                          tooltip: 'Clear birthday',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _birthday = null),
                        ),
                ),
                isEmpty: _birthday == null,
                child: Text(_birthday == null ? '' : MaterialLocalizations.of(context).formatMediumDate(_birthday!)),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.onboarding ? 'Save and continue' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboard,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      textCapitalization: capitalization,
      keyboardType: keyboard ?? (maxLines > 1 ? TextInputType.multiline : null),
      maxLines: maxLines,
      minLines: 1,
      validator: validator,
    );
  }

  void _removeRow(List<_Row> rows, _Row r) {
    setState(() => rows.remove(r));
    // The field still uses the controller until this frame finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => r.controller.dispose());
  }

  /// Label dropdown + value field per row, a remove button when there's more
  /// than one row, and an "Add" button up to 5 rows.
  List<Widget> _rows(
    List<_Row> rows,
    List<String> labels,
    String noun,
    TextInputType keyboard,
    FormFieldValidator<String> validator,
    String Function() nextLabel,
  ) {
    return [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 116,
                child: DropdownButtonFormField<String>(
                  initialValue: labels.contains(r.label) ? r.label : 'other',
                  isExpanded: true,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                  items: [for (final l in labels) DropdownMenuItem(value: l, child: Text(labelName(l)))],
                  onChanged: (v) => setState(() => r.label = v ?? r.label),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: r.controller,
                  decoration: InputDecoration(labelText: noun),
                  keyboardType: keyboard,
                  validator: validator,
                ),
              ),
              if (rows.length > 1)
                IconButton(
                  tooltip: 'Remove',
                  padding: const EdgeInsets.only(top: 12),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () => _removeRow(rows, r),
                ),
            ],
          ),
        ),
      if (rows.length < 5)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text('Add ${noun.toLowerCase()}'),
            onPressed: () => setState(() => rows.add(_Row(nextLabel(), ''))),
          ),
        ),
    ];
  }
}

String? _validatePhone(String? v) {
  final s = (v ?? '').trim();
  return s.isEmpty || RegExp(r'^[0-9+()\-.\s]{3,40}$').hasMatch(s) ? null : 'Digits, spaces and + ( ) - .';
}

String? _validateEmail(String? v) {
  final s = (v ?? '').trim();
  return s.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s) ? null : 'Not a valid email';
}
