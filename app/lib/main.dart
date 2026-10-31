import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'auth.dart';
import 'config.dart';
import 'models.dart';
import 'screens/groups_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final missing = Config.missing();
  if (missing.isNotEmpty) {
    runApp(_ConfigErrorApp(missing));
    return;
  }

  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabasePublishableKey);
  await initGoogleSignIn();
  runApp(const AutoContactApp());
}

class AutoContactApp extends StatelessWidget {
  const AutoContactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoContact',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

/// Shows the app when signed in and the sign-in screen otherwise,
/// so no group screen is reachable while signed out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final session = auth.currentSession;
        // Keyed by user so switching accounts starts over.
        return session == null ? const SignInScreen() : ProfileGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Loads your card, and sends you through onboarding first if you don't
/// have one yet.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final _api = Api();

  /// Your card, shared with every screen so edits show up everywhere at once.
  final _profile = ValueNotifier<ContactCard?>(null);
  late Future<ContactCard?> _loading = _load();

  Future<ContactCard?> _load() async => _profile.value = await _api.getProfile();

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContactCard?>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't reach AutoContact",
              message: '${snapshot.error}',
              actions: [
                FilledButton.tonal(
                  onPressed: () => setState(() => _loading = _load()),
                  child: const Text('Try again'),
                ),
                TextButton(onPressed: signOut, child: const Text('Sign out')),
              ],
            ),
          );
        }
        return ValueListenableBuilder<ContactCard?>(
          valueListenable: _profile,
          builder: (context, profile, _) => profile == null
              ? ProfileScreen(api: _api, onboarding: true, onSaved: (card) => _profile.value = card)
              : GroupsScreen(api: _api, profile: _profile),
        );
      },
    );
  }
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp(this.missing);

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Missing config: ${missing.join(', ')}\n\n'
              'Run with --dart-define-from-file=config.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
