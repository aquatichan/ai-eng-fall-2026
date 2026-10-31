// Values come from `--dart-define-from-file=config.json` (see config.example.json).
class Config {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // The *Web* OAuth client ID. Google puts it in the ID token's audience,
  // which is what Supabase checks.
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static List<String> missing() => [
        if (apiBaseUrl.isEmpty) 'API_BASE_URL',
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
        if (googleWebClientId.isEmpty) 'GOOGLE_WEB_CLIENT_ID',
      ];
}
