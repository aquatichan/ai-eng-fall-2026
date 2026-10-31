import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

Future<void> initGoogleSignIn() {
  // On iOS the client ID comes from GIDClientID in Info.plist.
  return GoogleSignIn.instance.initialize(serverClientId: Config.googleWebClientId);
}

/// Shows the Google account picker, then exchanges the Google ID token for a
/// Supabase session. Returns false if the user cancelled.
Future<bool> signInWithGoogle() async {
  final GoogleSignInAccount account;
  try {
    account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return false;
    rethrow;
  }

  final idToken = account.authentication.idToken;
  if (idToken == null) throw StateError('Google did not return an ID token');

  await Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
  );
  return true;
}

Future<void> signOut() async {
  await Supabase.instance.client.auth.signOut();
  await GoogleSignIn.instance.signOut();
}
