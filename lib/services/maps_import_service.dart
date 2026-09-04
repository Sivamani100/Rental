import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

/// Holds data extracted from a Google Maps link.
class MapsImportResult {
  final String? title;
  final String? address;
  final String? city;
  final String? area;
  final String? phone;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? propertyType;
  final List<String> amenities;
  final String? price;

  const MapsImportResult({
    this.title,
    this.address,
    this.city,
    this.area,
    this.phone,
    this.description,
    this.latitude,
    this.longitude,
    this.propertyType,
    this.amenities = const [],
    this.price,
  });

  bool get hasAnyData =>
      title != null ||
      address != null ||
      phone != null ||
      latitude != null ||
      description != null;
}

class MapsImportService {
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  /// Main entry point. Accepts any Google Maps URL format.
  static Future<MapsImportResult> importFromUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) throw Exception('Please paste a Google Maps link.');

    // Step 1: Resolve shortened links
    final resolvedUrl = await _resolveUrl(trimmed);
    debugPrint('[MapsImport] Resolved URL: $resolvedUrl');

    // Step 2: Parse coords + name from URL
    final parsedCoords = _parseCoordsFromUrl(resolvedUrl);
    final parsedName = _parsePlaceNameFromUrl(resolvedUrl);
    debugPrint('[MapsImport] Name: $parsedName, Coords: $parsedCoords');

    // Step 3: AI extraction
    final aiResult = await _extractViaAI(resolvedUrl, parsedName, parsedCoords);

    // Step 4: Merge (URL coords take priority — more precise)
    return MapsImportResult(
      title: aiResult.title ?? parsedName,
      address: aiResult.address,
      city: aiResult.city,
      area: aiResult.area,
      phone: aiResult.phone,
      description: aiResult.description,
      latitude: parsedCoords?.$1 ?? aiResult.latitude,
      longitude: parsedCoords?.$2 ?? aiResult.longitude,
      propertyType: aiResult.propertyType,
      amenities: aiResult.amenities,
      price: aiResult.price,
    );
  }

  /// Follows HTTP redirects to resolve short URLs (goo.gl, maps.app.goo.gl).
  static Future<String> _resolveUrl(String url) async {
    if (kIsWeb) return url; // CORS blocks redirect following on web

    try {
      final client = http.Client();
      var currentUrl = url;
      for (int i = 0; i < 5; i++) {
        final uri = Uri.parse(currentUrl);
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers['User-Agent'] =
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36';
        final response = await client.send(request);
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          if (location == null) break;
          currentUrl = location.startsWith('http')
              ? location
              : uri.resolve(location).toString();
        } else {
          break;
        }
      }
      client.close();
      return currentUrl;
    } catch (e) {
      debugPrint('[MapsImport] URL resolve error: $e');
      return url;
    }
  }

  /// Extracts lat/lng from @lat,lng pattern in full Google Maps URL.
  static (double, double)? _parseCoordsFromUrl(String url) {
    try {
      final m1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
      if (m1 != null) {
        return (double.parse(m1.group(1)!), double.parse(m1.group(2)!));
      }
      final m2 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
      if (m2 != null) {
        return (double.parse(m2.group(1)!), double.parse(m2.group(2)!));
      }
    } catch (_) {}
    return null;
  }

  /// Extracts place name from /maps/place/NAME/ path segment.
  static String? _parsePlaceNameFromUrl(String url) {
    try {
      final segments = Uri.parse(url).pathSegments;
      final idx = segments.indexOf('place');
      if (idx != -1 && idx + 1 < segments.length) {
        return Uri.decodeComponent(segments[idx + 1])
            .replaceAll('+', ' ')
            .trim();
      }
    } catch (_) {}
    return null;
  }

  /// Calls OpenRouter AI to extract property details from the Maps URL.
  static Future<MapsImportResult> _extractViaAI(
    String url,
    String? parsedName,
    (double, double)? coords,
  ) async {
    final apiKey = Env.openRouterApiKey;
    if (apiKey.isEmpty) {
      throw Exception('AI service not configured.');
    }

    final coordHint = coords != null
        ? 'GPS coordinates from URL: lat=${coords.$1}, lng=${coords.$2}.'
        : '';
    final nameHint =
        parsedName != null ? 'Place name extracted from URL: "$parsedName".' : '';

    final prompt = '''
You are a real-estate data extraction assistant. Extract real details for the property at this Google Maps link:

URL: $url

$nameHint $coordHint

Return ONLY a valid JSON object (no markdown, no explanation):
{
  "title": "exact name of the hostel/PG/flat/property",
  "address": "full street address",
  "city": "city name",
  "area": "neighbourhood/locality",
  "phone": "phone number if on Google Maps, else null",
  "description": "1-2 sentence description based on what you know",
  "latitude": number_or_null,
  "longitude": number_or_null,
  "propertyType": "PG" or "Rental" or "Buy",
  "amenities": ["Wi-Fi", "AC", "Food", ...],
  "price": "price/rent if known, else null"
}

Important: 
- Use ONLY real known data. Do NOT hallucinate.
- If coordinates are provided above, use them.
- propertyType: "PG" for hostels/PG/paying-guest, "Rental" for flats/apartments, "Buy" for sale/plots.
''';

    try {
      final response = await http
          .post(
            Uri.parse(_openRouterUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://rental.arkiolabs.com',
              'X-Title': 'Rental App Maps Import',
            },
            body: jsonEncode({
              'model': 'google/gemini-flash-1.5',
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'temperature': 0.1,
              'max_tokens': 800,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('AI service error (${response.statusCode}).');
      }

      final body = jsonDecode(response.body);
      final content =
          body['choices']?[0]?['message']?['content'] as String? ?? '';
      debugPrint('[MapsImport] AI response: $content');
      return _parseAiJson(content, coords);
    } catch (e) {
      debugPrint('[MapsImport] AI error: $e');
      return MapsImportResult(
        title: parsedName,
        latitude: coords?.$1,
        longitude: coords?.$2,
      );
    }
  }

  static MapsImportResult _parseAiJson(
      String content, (double, double)? urlCoords) {
    try {
      var clean = content.trim();
      clean = clean.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
      final json = jsonDecode(clean) as Map<String, dynamic>;

      final amenities = (json['amenities'] is List)
          ? (json['amenities'] as List)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];

      double? lat = urlCoords?.$1;
      double? lng = urlCoords?.$2;
      if (lat == null && json['latitude'] != null) {
        lat = (json['latitude'] as num).toDouble();
      }
      if (lng == null && json['longitude'] != null) {
        lng = (json['longitude'] as num).toDouble();
      }

      return MapsImportResult(
        title: _str(json['title']),
        address: _str(json['address']),
        city: _str(json['city']),
        area: _str(json['area']),
        phone: _str(json['phone']),
        description: _str(json['description']),
        latitude: lat,
        longitude: lng,
        propertyType: _str(json['propertyType']),
        amenities: amenities,
        price: _str(json['price']),
      );
    } catch (e) {
      debugPrint('[MapsImport] JSON parse error: $e');
      return MapsImportResult(
        latitude: urlCoords?.$1,
        longitude: urlCoords?.$2,
      );
    }
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }
}
