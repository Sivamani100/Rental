/// All secrets are injected at build time via --dart-define flags.
/// NEVER add hardcoded fallback values here.
/// On Vercel: set OPENROUTER_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY
/// in the Vercel dashboard → Project Settings → Environment Variables.
class Env {
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY');

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
}
