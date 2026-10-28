import 'package:flutter/material.dart';

import '../api.dart';
import '../auth.dart';
import '../models.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, this.api});

  final Api? api;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final Api _api = widget.api ?? Api();
  late Future<List<Group>> _groups = _api.getGroups();

  Future<void> _refresh() async {
    final next = _api.getGroups();
    setState(() => _groups = next);
    await next.catchError((_) => <Group>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your groups'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Group>>(
          future: _groups,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Message('Could not load groups: ${snapshot.error}\n\nPull to retry.');
            }
            final groups = snapshot.data!;
            if (groups.isEmpty) {
              return const _Message('No groups yet.');
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final g = groups[i];
                return ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(g.name),
                  subtitle: Text(g.isOwner ? 'Owner · ${g.displayCode}' : g.displayCode),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Centered text that still supports pull-to-refresh.
class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 120),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
