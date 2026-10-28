import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'config.dart';
import 'screens/groups_screen.dart';
import 'screens/sign_in_screen.dart';

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
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Shows the groups list when signed in and the sign-in screen otherwise,
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
        // Keyed by user so switching accounts rebuilds the groups screen.
        return session == null
            ? const SignInScreen()
            : GroupsScreen(key: ValueKey(session.user.id));
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
