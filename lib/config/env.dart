import 'dart:convert';

class Env {
  static final String openRouterApiKey = const String.fromEnvironment('OPENROUTER_API_KEY').isNotEmpty
      ? const String.fromEnvironment('OPENROUTER_API_KEY')
      : utf8.decode(base64.decode('c2stb3ItdjEtOGVhMGViOTk1NDM1YzZhNWIzNTM1YmYzNmVmMzM4YWQ0NmJlYzNlMmMxMDBkNWRiMmQ5MTM4NmRlZWVjZDYxOQ=='));
}
