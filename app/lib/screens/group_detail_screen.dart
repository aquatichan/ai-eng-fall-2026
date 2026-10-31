import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../contacts.dart';
import '../models.dart';
import '../widgets.dart';
import 'card_screen.dart';
import 'profile_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.api, required this.group, required this.profile});

  final Api api;

  /// Shown in the app bar while the full detail loads.
  final Group group;

  final ValueNotifier<ContactCard?> profile;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with AutoRefresh {
  GroupDetail? _detail;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    reload();
    // Your own card changed (edited from this screen or another): show it now.
    widget.profile.addListener(reload);
  }

  @override
  void dispose() {
    widget.profile.removeListener(reload);
    super.dispose();
  }

  /// Fetches the roster, keeping the current one on screen meanwhile.
  @override
  Future<void> reload({bool userInitiated = false}) async {
    try {
      final detail = await widget.api.getGroup(widget.group.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_detail == null) {
        setState(() => _error = e);
      } else if (userInitiated) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not refresh: $e')));
      }
    }
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<ContactCard>(
      MaterialPageRoute(builder: (_) => ProfileScreen(api: widget.api, initial: widget.profile.value)),
    );
    if (saved != null) widget.profile.value = saved;
  }

  void _openCard(Member m, bool isMe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardScreen(
          member: m,
          isMe: isMe,
          onEdit: () async {
            Navigator.of(context).pop();
            await _editProfile();
          },
        ),
      ),
    );
  }

  void _copyCode(Group group) {
    Clipboard.setData(ClipboardData(text: group.displayCode));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join code copied')));
  }

  Future<void> _shareCode(Group group, BuildContext buttonContext) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join "${group.name}" on AutoContact with code ${group.displayCode}',
        sharePositionOrigin: _originOf(buttonContext),
      ),
    );
  }

  Future<void> _sync(List<Member> others) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await syncToContacts(others);
      messenger.showSnackBar(SnackBar(content: Text(result.summary)));
    } on ContactsPermissionDenied catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          action: e.permanently ? SnackBarAction(label: 'Settings', onPressed: openContactsSettings) : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not sync: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(GroupDetail detail, BuildContext buttonContext) async {
    try {
      await shareRosterVCard(detail.group.name, detail.members, origin: _originOf(buttonContext));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.group.name ?? widget.group.name)),
      body: RefreshIndicator(
        onRefresh: () => reload(userInitiated: true),
        child: switch ((detail, _error)) {
          (null, null) => const Center(child: CircularProgressIndicator()),
          (null, final error?) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load this group",
              message: '$error',
              actions: [
                FilledButton.tonal(onPressed: () => reload(userInitiated: true), child: const Text('Try again')),
              ],
            ),
          (final detail?, _) => _roster(detail),
        },
      ),
    );
  }

  Widget _roster(GroupDetail detail) {
    // You're already in your own Contacts.
    final others = detail.members.where((m) => m.userId != detail.meId).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _JoinCodeCard(
          group: detail.group,
          onCopy: () => _copyCode(detail.group),
          onShare: (buttonContext) => _shareCode(detail.group, buttonContext),
        ),
        const SizedBox(height: 12),
        _ContactsCard(
          othersCount: others.length,
          busy: _busy,
          onSync: () => _sync(others),
          onExport: (buttonContext) => _export(detail, buttonContext),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: SectionLabel('Members · ${detail.members.length}'),
        ),
        Card(
          child: Column(
            children: [
              for (final (i, m) in detail.members.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                _MemberTile(
                  member: m,
                  isMe: m.userId == detail.meId,
                  onTap: () => _openCard(m, m.userId == detail.meId),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Where a button sits on screen, to anchor the share sheet on iPad.
Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.group, required this.onCopy, required this.onShare});

  final Group group;
  final VoidCallback onCopy;
  final void Function(BuildContext buttonContext) onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JOIN CODE',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                group.displayCode,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Anyone with this code can join and see the roster.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  color: scheme.onPrimaryContainer,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: onCopy,
                ),
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: 'Share code',
                    color: scheme.onPrimaryContainer,
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () => onShare(buttonContext),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({
    required this.othersCount,
    required this.busy,
    required this.onSync,
    required this.onExport,
  });

  final int othersCount;
  final bool busy;
  final VoidCallback onSync;
  final void Function(BuildContext buttonContext) onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = othersCount == 1 ? '1 person' : '$othersCount people';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Save to your phone', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              othersCount == 0
                  ? "Once others join, you can add them to Contacts here."
                  : 'Adds $people to Contacts, and brings anyone you already have up to date. Nothing is deleted.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded),
              label: Text(othersCount == 0 ? 'Nobody to add yet' : 'Sync $people to Contacts'),
              onPressed: busy || othersCount == 0 ? null : onSync,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (buttonContext) => OutlinedButton.icon(
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Export as contact file (.vcf)'),
                onPressed: busy ? null : () => onExport(buttonContext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isMe, required this.onTap});

  final Member member;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = member.card;
    final work = [card.jobTitle, card.company].where((s) => s != null && s.isNotEmpty).join(' · ');
    final firstDetail = card.phones.firstOrNull?.value ?? card.emails.firstOrNull?.value;
    final subtitle = [if (work.isNotEmpty) work, ?firstDetail].join('\n');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: NameAvatar(member.name),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(member.name, style: theme.textTheme.titleSmall),
          if (isMe) const Tag('You'),
          if (member.isOwner) const Tag('Owner'),
        ],
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
