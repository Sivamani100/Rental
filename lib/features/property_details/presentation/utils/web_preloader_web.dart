// Web implementation to read preloaded property from index.html sessionStorage
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Map<String, dynamic>? getWebPreloadedProperty(String propertyId) {
  try {
    final raw = html.window.sessionStorage['preloaded_property_$propertyId'];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
  } catch (_) {}
  return null;
}
