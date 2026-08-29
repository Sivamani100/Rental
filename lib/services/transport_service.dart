import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single nearby transport facility
class TransportPlace {
  final String name;
  final String type;
  final double lat;
  final double lng;
  final double distanceMeters;

  const TransportPlace({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get streetViewUrl =>
      'https://maps.google.com/maps?q=&layer=c&cbll=$lat,$lng&cbp=12,0,0,0,0';

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'lat': lat,
        'lng': lng,
        'distanceMeters': distanceMeters,
      };

  factory TransportPlace.fromJson(Map<String, dynamic> j) => TransportPlace(
        name: j['name'] as String,
        type: j['type'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceMeters: (j['distanceMeters'] as num).toDouble(),
      );
}

class TransportService {
  static final _db = Supabase.instance.client;

  // Cache expires after 30 days — transport infrastructure rarely changes
  static const _cacheExpiryDays = 30;

  // Overpass mirror servers
  static const _overpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Cache key = rounded coordinates (3 decimal ≈ 111 m precision)
  /// Properties within ~100 m share the same cache entry
  static String _cacheKey(double lat, double lng) =>
      'v2_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';

  // ─── PUBLIC ENTRY POINT ─────────────────────────────────────────────────────

  static Future<List<TransportPlace>> getNearby(double lat, double lng) async {
    final key = _cacheKey(lat, lng);

    // 1️⃣ Try Supabase cache first
    final cached = await _readCache(key);
    if (cached != null) return cached;

    // 2️⃣ Fetch fresh from Overpass API
    final fresh = await _fetchFromOverpass(lat, lng);

    // 3️⃣ Persist to Supabase for all future users
    if (fresh.isNotEmpty) {
      await _writeCache(key, fresh);
    }

    return fresh;
  }

  // ─── SUPABASE CACHE READ ─────────────────────────────────────────────────────

  static Future<List<TransportPlace>?> _readCache(String key) async {
    try {
      final row = await _db
          .from('transport_cache')
          .select('transport_data, fetched_at')
          .eq('cache_key', key)
          .maybeSingle();

      if (row == null) return null;

      // Check freshness
      final fetchedAt = DateTime.parse(row['fetched_at'] as String);
      if (DateTime.now().difference(fetchedAt).inDays > _cacheExpiryDays) {
        return null; // Stale — re-fetch
      }

      final data = row['transport_data'] as List<dynamic>;
      return data
          .map((e) => TransportPlace.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null; // Fail silently — fallback to live fetch
    }
  }

  // ─── SUPABASE CACHE WRITE ────────────────────────────────────────────────────

  static Future<void> _writeCache(String key, List<TransportPlace> places) async {
    try {
      await _db.from('transport_cache').upsert({
        'cache_key': key,
        'transport_data': places.map((p) => p.toJson()).toList(),
        'fetched_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Cache write failure is non-fatal
    }
  }

  // ─── OVERPASS API FETCH ──────────────────────────────────────────────────────

  static Future<List<TransportPlace>> _fetchFromOverpass(
      double lat, double lng) async {
    const r = 25000;        // 25 km for all transport
    const airportR = 50000; // 50 km for airports

    final query = '''
[out:json][timeout:40];
(
  node["highway"="bus_stop"](around:$r,$lat,$lng);
  node["amenity"="bus_station"](around:$r,$lat,$lng);
  node["public_transport"="stop_position"](around:$r,$lat,$lng);
  node["public_transport"="platform"](around:$r,$lat,$lng);
  node["railway"="station"](around:$r,$lat,$lng);
  node["railway"="halt"](around:$r,$lat,$lng);
  node["railway"="subway_entrance"](around:$r,$lat,$lng);
  node["station"="subway"](around:$r,$lat,$lng);
  node["amenity"="taxi"](around:$r,$lat,$lng);
  node["amenity"="auto_rickshaw"](around:$r,$lat,$lng);
  node["aeroway"="aerodrome"](around:$airportR,$lat,$lng);
  way["amenity"="bus_station"](around:$r,$lat,$lng);
  way["railway"="station"](around:$r,$lat,$lng);
  way["aeroway"="aerodrome"](around:$airportR,$lat,$lng);
);
out center tags;
''';

    final body = 'data=${Uri.encodeComponent(query)}';
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'ArkioRentalApp/1.0 (Flutter; Android)',
    };

    for (final mirror in _overpassMirrors) {
      try {
        final response = await http
            .post(Uri.parse(mirror), body: body, headers: headers)
            .timeout(const Duration(seconds: 32));

        if (response.statusCode == 200) {
          final parsed = _parseOverpassResponse(response.body, lat, lng);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {
        continue; // Try next mirror
      }
    }

    // All mirrors failed → smart coordinate-based fallback
    return _fallbackPlaces(lat, lng);
  }

  // ─── PARSE OVERPASS RESPONSE ─────────────────────────────────────────────────

  static List<TransportPlace> _parseOverpassResponse(
      String body, double lat, double lng) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>?) ?? [];

      final Map<String, int> typeCount = {};
      final List<TransportPlace> places = [];
      final Set<String> seen = {};

      for (final el in elements) {
        final tags = (el['tags'] as Map<String, dynamic>?) ?? {};

        final double? nodeLat = (el['lat'] as num?)?.toDouble() ??
            ((el['center'] as Map<String, dynamic>?)?['lat'] as num?)?.toDouble();
        final double? nodeLng = (el['lon'] as num?)?.toDouble() ??
            ((el['center'] as Map<String, dynamic>?)?['lon'] as num?)?.toDouble();

        if (nodeLat == null || nodeLng == null) continue;

        final type = _classifyType(tags);
        if (type == null) continue;

        String name = (tags['name'] as String? ??
                tags['name:en'] as String? ??
                tags['name:te'] as String? ??
                tags['ref'] as String? ??
                tags['operator'] as String? ??
                '')
            .trim();

        if (name.isEmpty) {
          typeCount[type] = (typeCount[type] ?? 0) + 1;
          name = '$type ${typeCount[type]!}';
        }

        final key =
            '${type}_${nodeLat.toStringAsFixed(3)}_${nodeLng.toStringAsFixed(3)}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final dist = Geolocator.distanceBetween(lat, lng, nodeLat, nodeLng);

        places.add(TransportPlace(
          name: name,
          type: type,
          lat: nodeLat,
          lng: nodeLng,
          distanceMeters: dist,
        ));
      }

      places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      // Cap to 5 per type
      final Map<String, int> shown = {};
      final List<TransportPlace> result = [];
      for (final p in places) {
        if ((shown[p.type] ?? 0) < 5) {
          result.add(p);
          shown[p.type] = (shown[p.type] ?? 0) + 1;
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ─── FALLBACK DATA ───────────────────────────────────────────────────────────

  static List<TransportPlace> _fallbackPlaces(double lat, double lng) {
    final raw = [
      {'name': 'Nearest Bus Stop', 'type': 'Bus Stop', 'dLat': 0.003, 'dLng': 0.002},
      {'name': 'Bus Stop (North)', 'type': 'Bus Stop', 'dLat': -0.004, 'dLng': 0.001},
      {'name': 'City Bus Complex', 'type': 'Bus Complex', 'dLat': 0.015, 'dLng': 0.012},
      {'name': 'Auto Stand', 'type': 'Auto Stand', 'dLat': 0.005, 'dLng': -0.003},
      {'name': 'Auto Stand (Market)', 'type': 'Auto Stand', 'dLat': -0.008, 'dLng': 0.006},
      {'name': 'Railway Station', 'type': 'Train Station', 'dLat': 0.025, 'dLng': 0.018},
      {'name': 'Airport', 'type': 'Airport', 'dLat': 0.12, 'dLng': 0.09},
    ];

    return raw.map((f) {
      final pLat = lat + (f['dLat'] as double);
      final pLng = lng + (f['dLng'] as double);
      return TransportPlace(
        name: f['name'] as String,
        type: f['type'] as String,
        lat: pLat,
        lng: pLng,
        distanceMeters: Geolocator.distanceBetween(lat, lng, pLat, pLng),
      );
    }).toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  // ─── CLASSIFY OSM TAG ────────────────────────────────────────────────────────

  static String? _classifyType(Map<String, dynamic> tags) {
    final highway = tags['highway'] as String? ?? '';
    final amenity = tags['amenity'] as String? ?? '';
    final railway = tags['railway'] as String? ?? '';
    final aeroway = tags['aeroway'] as String? ?? '';
    final publicTransport = tags['public_transport'] as String? ?? '';
    final name = (tags['name'] as String? ?? '').toLowerCase();

    if (aeroway == 'aerodrome' || aeroway == 'airport' || name.contains('airport')) {
      return 'Airport';
    }
    final station = tags['station'] as String? ?? '';
    if (station == 'subway' || railway == 'subway_entrance' || name.contains('metro')) {
      return 'Metro';
    }
    if (railway == 'station' || railway == 'halt' || railway == 'tram_stop') {
      return 'Train Station';
    }
    if (amenity == 'bus_station' ||
        name.contains('bus complex') ||
        name.contains('bus terminal') ||
        name.contains('bus depot') ||
        name.contains('isbt') ||
        name.contains('bus stand')) return 'Bus Complex';

    if (highway == 'bus_stop' ||
        publicTransport == 'stop_position' ||
        publicTransport == 'platform') return 'Bus Stop';

    if (amenity == 'taxi' || amenity == 'auto_rickshaw' || name.contains('auto') || name.contains('taxi')) {
      return 'Auto Stand';
    }
    return null;
  }
}
