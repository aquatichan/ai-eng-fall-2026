import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../widgets.dart';
import 'card_screen.dart';
import 'group_detail_screen.dart';
import 'profile_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.api, required this.profile, required this.meId});

  final Api api;
  final String meId;

  /// Your card. Editing it here updates every screen that shows it.
  final ValueNotifier<ContactCard?> profile;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with AutoRefresh {
  List<Group>? _groups;
  Object? _error;

  Api get _api => widget.api;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Fetches the list, keeping the current one on screen meanwhile. A failed
  /// background reload keeps showing the last good list.
  @override
  Future<void> reload({bool userInitiated = false}) async {
    try {
      final groups = await _api.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_groups == null) {
        setState(() => _error = e);
      } else if (userInitiated) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not refresh: $e')));
      }
    }
  }

  Future<void> _open(Group group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(api: _api, group: group, profile: widget.profile, meId: widget.meId),
      ),
    );
    if (mounted) await reload();
  }

  Future<void> _addGroup() async {
    final action = await showModalBottomSheet<_AddAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetOption(
                icon: Icons.group_add_rounded,
                title: 'Create a group',
                detail: "You'll get a code to share with your crew.",
                onTap: () => Navigator.pop(context, _AddAction.create),
              ),
              _SheetOption(
                icon: Icons.vpn_key_rounded,
                title: 'Join with a code',
                detail: 'Enter the code someone shared, like ABC-123.',
                onTap: () => Navigator.pop(context, _AddAction.join),
              ),
            ],
          ),
        ),
      ),
    );
    if (action != null && mounted) await _runAction(action);
  }

  Future<void> _runAction(_AddAction action) async {
    final create = action == _AddAction.create;
    final group = await showDialog<Group>(
      context: context,
      builder: (_) => _TextActionDialog(
        title: create ? 'Create a group' : 'Join a group',
        label: create ? 'Group name' : 'Join code',
        hint: create ? 'e.g. Stage crew' : 'ABC-123',
        submitLabel: create ? 'Create' : 'Join',
        maxLength: create ? 100 : null,
        capitalization: create ? TextCapitalization.sentences : TextCapitalization.characters,
        inputFormatters: create ? const [] : [JoinCodeFormatter()],
        keyboard: create ? TextInputType.text : TextInputType.visiblePassword,
        onSubmit: create ? _api.createGroup : _api.joinGroup,
      ),
    );
    if (group != null && mounted) await _open(group);
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<ContactCard>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(api: _api, meId: widget.meId, initial: widget.profile.value),
      ),
    );
    if (saved != null) widget.profile.value = saved;
  }

  Future<void> _openAccountMenu(ContactCard me) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    final choice = await showModalBottomSheet<_AccountAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: NameAvatar(me.fullName),
                title: Text(me.fullName),
                subtitle: email == null ? null : Text('Signed in as $email'),
              ),
              const Divider(),
              _SheetOption(
                icon: Icons.badge_rounded,
                title: 'My info',
                detail: 'Edit the card every group gets.',
                onTap: () => Navigator.pop(context, _AccountAction.edit),
              ),
              _SheetOption(
                icon: Icons.qr_code_2_rounded,
                title: 'My QR code',
                detail: 'Anyone can scan it to add you to Contacts.',
                onTap: () => Navigator.pop(context, _AccountAction.qr),
              ),
              _SheetOption(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                detail: 'Your card and groups stay saved.',
                onTap: () => Navigator.pop(context, _AccountAction.signOut),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _AccountAction.edit:
        await _editProfile();
      case _AccountAction.qr:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyQrScreen(card: me)));
      case _AccountAction.signOut:
        await signOut();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your groups'),
        actions: [
          ValueListenableBuilder<ContactCard?>(
            valueListenable: widget.profile,
            builder: (context, me, _) => IconButton(
              tooltip: 'My info',
              icon: NameAvatar(me?.fullName ?? '', radius: 16),
              onPressed: me == null ? null : () => _openAccountMenu(me),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // The empty state has its own buttons, so the FAB only shows once there are groups.
      floatingActionButton: (groups?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New group'),
              onPressed: _addGroup,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => reload(userInitiated: true),
        child: switch ((groups, _error)) {
          (null, null) => const Center(child: CircularProgressIndicator()),
          (null, final error?) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your groups",
              message: '$error',
              actions: [
                FilledButton.tonal(onPressed: () => reload(userInitiated: true), child: const Text('Try again')),
              ],
            ),
          (final groups?, _) when groups.isEmpty => EmptyState(
              icon: Icons.groups_rounded,
              title: 'No groups yet',
              message: 'Create a group for your crew, or join one with a code someone shared with you.',
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Create a group'),
                  onPressed: () => _runAction(_AddAction.create),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.vpn_key_rounded),
                  label: const Text('Join with a code'),
                  onPressed: () => _runAction(_AddAction.join),
                ),
              ],
            ),
          (final groups?, _) => ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              // Bottom padding keeps the last card clear of the FAB.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _GroupCard(group: groups[i], onTap: () => _open(groups[i])),
            ),
        },
      ),
    );
  }
}

enum _AccountAction { edit, qr, signOut }

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              NameAvatar(group.name, radius: 24, square: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(group.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                        ),
                        if (group.isOwner) ...[const SizedBox(width: 8), const Tag('Owner')],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.displayCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({required this.icon, required this.title, required this.detail, required this.onTap});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: scheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: Text(detail),
      onTap: onTap,
    );
  }
}

enum _AddAction { create, join }

/// One-field dialog that runs [onSubmit] and pops its result, showing the
/// server's error inline so the user can fix the input and retry.
class _TextActionDialog extends StatefulWidget {
  const _TextActionDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.capitalization,
    required this.onSubmit,
    this.maxLength,
    this.hint,
    this.inputFormatters = const [],
    this.keyboard,
  });

  final String title;
  final String label;
  final String? hint;
  final String submitLabel;
  final int? maxLength;
  final TextCapitalization capitalization;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType? keyboard;
  final Future<Group> Function(String value) onSubmit;

  @override
  State<_TextActionDialog> createState() => _TextActionDialogState();
}

class _TextActionDialogState extends State<_TextActionDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await widget.onSubmit(value);
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        maxLength: widget.maxLength,
        textCapitalization: widget.capitalization,
        inputFormatters: widget.inputFormatters,
        keyboardType: widget.keyboard,
        autocorrect: false,
        decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}
