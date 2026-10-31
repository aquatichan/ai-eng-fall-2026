import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../contacts.dart';
import '../models.dart';
import '../widgets.dart';

/// A person's card, read-only. For someone else it offers "Save to Contacts";
/// for you it offers [onEdit] and your QR code.
class CardScreen extends StatefulWidget {
  const CardScreen({super.key, required this.member, required this.meId, this.onEdit});

  final Member member;
  final String meId;
  final VoidCallback? onEdit;

  bool get isMe => member.userId == meId;

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await syncToContacts([widget.member], meId: widget.meId);
      messenger.showSnackBar(SnackBar(content: Text(result.summary)));
    } on ContactsPermissionDenied catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          action: e.permanently ? SnackBarAction(label: 'Settings', onPressed: openContactsSettings) : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $text')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.member.card;
    final work = [card.jobTitle, card.company].where((s) => s != null && s.isNotEmpty).join(' · ');
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.isMe && widget.onEdit != null)
            IconButton(tooltip: 'Edit my info', icon: const Icon(Icons.edit_rounded), onPressed: widget.onEdit),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(child: NameAvatar(card.fullName, radius: 44)),
          const SizedBox(height: 16),
          Text(card.fullName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          if (work.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              work,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [if (widget.isMe) const Tag('You'), if (widget.member.isOwner) const Tag('Owner')],
          ),
          const SizedBox(height: 20),
          if (widget.isMe)
            FilledButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Show my QR code'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MyQrScreen(card: card)),
              ),
            )
          else
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Save to Contacts'),
              onPressed: _busy ? null : _save,
            ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                for (final p in card.phones) _info(Icons.phone_rounded, labelName(p.label), p.value),
                for (final e in card.emails) _info(Icons.mail_rounded, labelName(e.label), e.value),
                if (card.website != null) _info(Icons.link_rounded, 'Website', card.website!),
                if (card.address != null) _info(Icons.home_rounded, 'Address', card.address!),
                if (card.birthday != null)
                  _info(
                    Icons.cake_rounded,
                    'Birthday',
                    MaterialLocalizations.of(context).formatMediumDate(card.birthday!),
                  ),
                if (card.phones.isEmpty &&
                    card.emails.isEmpty &&
                    card.website == null &&
                    card.address == null &&
                    card.birthday == null)
                  const Padding(padding: EdgeInsets.all(24), child: Text('No contact details yet.')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One detail row. Long-press copies the value.
  Widget _info(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(value),
      subtitle: Text(label),
      onLongPress: () => _copy(value),
    );
  }
}

/// Your card as a QR code. Pointing any phone's camera at it offers "Add to
/// Contacts", no app needed.
class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key, required this.card});

  final ContactCard card;

  Future<void> _shareFile(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final dir = await getTemporaryDirectory();
    final name = card.fullName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final file = File('${dir.path}/${name.isEmpty ? 'contact' : name}.vcf');
    await file.writeAsString(cardVCard(card));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/vcard')],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My QR code')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // QR codes need dark-on-light to scan reliably, even in dark mode.
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: qrVCard(card),
                size: 260,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(card.fullName, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            "Point any phone's camera at this code to add you to Contacts. They don't need AutoContact.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share as contact file (.vcf)'),
              onPressed: () => _shareFile(buttonContext),
            ),
          ),
        ],
      ),
    );
  }
}
