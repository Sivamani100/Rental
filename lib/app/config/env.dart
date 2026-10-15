/// All secrets are injected at build time via --dart-define flags.
/// NEVER add hardcoded fallback values here.
/// On Vercel: set OPENROUTER_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY
/// in the Vercel dashboard → Project Settings → Environment Variables.
class Env {
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY');

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dhbwnteiahefjfpojapz.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYndudGVpYWhlZmpmcG9qYXB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NDIwNTQsImV4cCI6MjEwMzIxODA1NH0.CnP-ogYh7FwPY9cqBRTX2oS6NqTT-mXgPsSyDDCADC8',
  );
}
