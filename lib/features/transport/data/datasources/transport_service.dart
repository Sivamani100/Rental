import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single nearby transport facility with real coordinates and exact calculated distance
class TransportPlace {
  final String name;
  final String type; // 'Bus Stop', 'Bus Complex', 'Train Station', 'Metro', 'Airport', 'Auto Stand'
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

  /// Recalculates distance dynamically from the given origin coordinates
  TransportPlace copyWithCalculatedDistance(double fromLat, double fromLng) {
    final dist = TransportService.calculateDistanceMeters(fromLat, fromLng, lat, lng);
    return TransportPlace(
      name: name,
      type: type,
      lat: lat,
      lng: lng,
      distanceMeters: dist,
    );
  }

  String get streetViewUrl =>
      'https://maps.google.com/maps?q=&layer=c&cbll=$lat,$lng&cbp=12,0,0,0,0';

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  String getDirectionsUrl(double fromLat, double fromLng) =>
      'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLng&destination=$lat,$lng&travelmode=driving';

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
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      );
}

class TransportService {
  static final _db = Supabase.instance.client;

  // Cache expires after 14 days
  static const _cacheExpiryDays = 14;

  // Cache key version 3: ensures all stale mock data is bypassed
  static String _cacheKey(double lat, double lng) =>
      'v3_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';

  /// Exact Haversine distance in meters between two coordinates
  static double calculateDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Identifies and discards legacy hardcoded mock entries
  static bool _isFakePlace(TransportPlace p) {
    final lower = p.name.toLowerCase().trim();
    return lower == 'nearest bus stop' ||
        lower == 'bus stop (north)' ||
        lower == 'city bus complex' ||
        lower == 'auto stand' ||
        lower == 'auto stand (market)' ||
        lower == 'railway station' ||
        lower == 'airport';
  }

  // ─── PUBLIC ENTRY POINT ─────────────────────────────────────────────────────

  static Future<List<TransportPlace>> getNearby(double lat, double lng) async {
    final key = _cacheKey(lat, lng);

    // 1️⃣ Try Supabase cache first (shared across all users)
    final supabaseCached = await _readCache(key);
    if (supabaseCached != null && supabaseCached.isNotEmpty) {
      final hasFakes = supabaseCached.any(_isFakePlace);
      if (!hasFakes) {
        // Recalculate exact distance from property
        return supabaseCached
            .map((p) => p.copyWithCalculatedDistance(lat, lng))
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      }
    }

    // 2️⃣ Try local SharedPrefs cache
    final localCached = await _readLocalCache(key);
    if (localCached != null && localCached.isNotEmpty) {
      final hasFakes = localCached.any(_isFakePlace);
      if (!hasFakes) {
        return localCached
            .map((p) => p.copyWithCalculatedDistance(lat, lng))
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      }
    }

    // 3️⃣ Fetch real live transport data from OpenStreetMap Nominatim & Overpass
    final fresh = await _fetchRealTransport(lat, lng);

    // 4️⃣ Persist valid real results to both Supabase and local storage
    if (fresh.isNotEmpty) {
      _writeCache(key, fresh);
      _writeLocalCache(key, fresh);
    }

    return fresh;
  }

  // ─── REAL TRANSPORT FETCHING ─────────────────────────────────────────────────

  static Future<List<TransportPlace>> _fetchRealTransport(
      double lat, double lng) async {
    final List<TransportPlace> allPlaces = [];
    final Set<String> seen = {};

    // Step A: Fetch real places via Nominatim (CORS compliant, reliable)
    try {
      final nominatimResults = await _fetchFromNominatim(lat, lng);
      for (final p in nominatimResults) {
        final key = '${p.type}_${p.lat.toStringAsFixed(3)}_${p.lng.toStringAsFixed(3)}';
        if (!seen.contains(key) && !_isFakePlace(p)) {
          seen.add(key);
          allPlaces.add(p);
        }
      }
    } catch (_) {}

    // Step B: If Bus Stops or Stations are scarce, fetch via Photon POI
    if (allPlaces.length < 4) {
      try {
        final photonResults = await _fetchFromPhoton(lat, lng);
        for (final p in photonResults) {
          final key = '${p.type}_${p.lat.toStringAsFixed(3)}_${p.lng.toStringAsFixed(3)}';
          if (!seen.contains(key) && !_isFakePlace(p)) {
            seen.add(key);
            allPlaces.add(p);
          }
        }
      } catch (_) {}
    }

    // Step C: Try Overpass for rich transit nodes if still under target
    if (allPlaces.length < 5) {
      try {
        final overpassResults = await _fetchFromOverpass(lat, lng);
        for (final p in overpassResults) {
          final key = '${p.type}_${p.lat.toStringAsFixed(3)}_${p.lng.toStringAsFixed(3)}';
          if (!seen.contains(key) && !_isFakePlace(p)) {
            seen.add(key);
            allPlaces.add(p);
          }
        }
      } catch (_) {}
    }

    // Sort strictly by exact distance
    allPlaces.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // Cap to at most 6 per transport category
    final Map<String, int> shown = {};
    final List<TransportPlace> filtered = [];
    for (final p in allPlaces) {
      if ((shown[p.type] ?? 0) < 6) {
        filtered.add(p);
        shown[p.type] = (shown[p.type] ?? 0) + 1;
      }
    }

    return filtered;
  }

  // ─── NOMINATIM POI FETCHER ───────────────────────────────────────────────────

  static Future<List<TransportPlace>> _fetchFromNominatim(
      double lat, double lng) async {
    final queries = [
      {'type': 'Bus Stop', 'q': 'bus stop', 'delta': 0.04, 'limit': 8},
      {'type': 'Bus Complex', 'q': 'bus station', 'delta': 0.12, 'limit': 8},
      {'type': 'Train Station', 'q': 'railway station', 'delta': 0.25, 'limit': 8},
      {'type': 'Metro', 'q': 'metro station', 'delta': 0.20, 'limit': 6},
      {'type': 'Airport', 'q': 'airport', 'delta': 0.55, 'limit': 4},
      {'type': 'Auto Stand', 'q': 'auto stand', 'delta': 0.05, 'limit': 6},
    ];

    final headers = {
      'User-Agent': 'ArkioRentalApp/1.0 (Mobile; Flutter)',
      'Accept': 'application/json',
    };

    final fetched = await Future.wait(queries.map((q) async {
      final delta = q['delta'] as double;
      final type = q['type'] as String;
      final limit = q['limit'] as int;
      final viewbox =
          '${lng - delta},${lat + delta},${lng + delta},${lat - delta}';
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q['q'] as String)}&format=json&viewbox=$viewbox&bounded=1&limit=$limit',
      );

      try {
        final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List<dynamic>;
          final List<TransportPlace> places = [];
          for (final item in list) {
            final nodeLat = double.tryParse(item['lat']?.toString() ?? '');
            final nodeLng = double.tryParse(item['lon']?.toString() ?? '');
            if (nodeLat == null || nodeLng == null) continue;

            String rawName = (item['name'] as String? ?? '').trim();
            if (rawName.isEmpty) {
              final disp = (item['display_name'] as String? ?? '').trim();
              if (disp.isNotEmpty) {
                rawName = disp.split(',').first.trim();
              }
            }
            if (rawName.isEmpty) rawName = type;

            final dist = calculateDistanceMeters(lat, lng, nodeLat, nodeLng);
            places.add(TransportPlace(
              name: rawName,
              type: type,
              lat: nodeLat,
              lng: nodeLng,
              distanceMeters: dist,
            ));
          }
          return places;
        }
      } catch (_) {}
      return <TransportPlace>[];
    }));

    return fetched.expand((x) => x).toList();
  }

  // ─── PHOTON POI FETCHER (KOMOOT OSM) ─────────────────────────────────────────

  static Future<List<TransportPlace>> _fetchFromPhoton(
      double lat, double lng) async {
    final targets = [
      {'type': 'Bus Stop', 'q': 'bus stop'},
      {'type': 'Bus Complex', 'q': 'bus station'},
      {'type': 'Train Station', 'q': 'railway station'},
      {'type': 'Metro', 'q': 'metro station'},
      {'type': 'Airport', 'q': 'airport'},
    ];

    final headers = {'User-Agent': 'ArkioRentalApp/1.0'};
    final results = await Future.wait(targets.map((t) async {
      final type = t['type'] as String;
      final q = t['q'] as String;
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&lat=$lat&lon=$lng&limit=5',
      );

      try {
        final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final features = (data['features'] as List<dynamic>?) ?? [];
          final List<TransportPlace> list = [];
          for (final f in features) {
            final props = (f['properties'] as Map<String, dynamic>?) ?? {};
            final coords = (f['geometry']?['coordinates'] as List<dynamic>?);
            if (coords == null || coords.length < 2) continue;

            final pLng = (coords[0] as num).toDouble();
            final pLat = (coords[1] as num).toDouble();

            final name = (props['name'] as String? ?? '').trim();
            if (name.isEmpty) continue;

            final dist = calculateDistanceMeters(lat, lng, pLat, pLng);
            // Cap reasonable radius
            if (type == 'Bus Stop' && dist > 5000) continue;
            if (type == 'Bus Complex' && dist > 15000) continue;
            if (type == 'Train Station' && dist > 25000) continue;
            if (type == 'Airport' && dist > 60000) continue;

            list.add(TransportPlace(
              name: name,
              type: type,
              lat: pLat,
              lng: pLng,
              distanceMeters: dist,
            ));
          }
          return list;
        }
      } catch (_) {}
      return <TransportPlace>[];
    }));

    return results.expand((x) => x).toList();
  }

  // ─── OVERPASS API FETCHER (FAST MIRRORS & OPTIMIZED RADII) ───────────────────

  static const _overpassMirrors = [
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static Future<List<TransportPlace>> _fetchFromOverpass(
      double lat, double lng) async {
    final query = '''
[out:json][timeout:10];
(
  node["highway"="bus_stop"](around:3000,$lat,$lng);
  node["amenity"="bus_station"](around:10000,$lat,$lng);
  node["railway"="station"](around:20000,$lat,$lng);
  node["station"="subway"](around:20000,$lat,$lng);
  node["aeroway"="aerodrome"](around:50000,$lat,$lng);
  way["amenity"="bus_station"](around:10000,$lat,$lng);
  way["railway"="station"](around:20000,$lat,$lng);
);
out center 40 tags;
''';

    final body = 'data=${Uri.encodeComponent(query)}';
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'ArkioRentalApp/1.0 (Flutter; Mobile)',
    };

    for (final mirror in _overpassMirrors) {
      try {
        final response = await http
            .post(Uri.parse(mirror), body: body, headers: headers)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final parsed = _parseOverpassResponse(response.body, lat, lng);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {
        continue;
      }
    }

    return [];
  }

  static List<TransportPlace> _parseOverpassResponse(
      String body, double lat, double lng) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>?) ?? [];

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
                tags['operator'] as String? ??
                '')
            .trim();

        if (name.isEmpty) continue;

        final key =
            '${type}_${nodeLat.toStringAsFixed(3)}_${nodeLng.toStringAsFixed(3)}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final dist = calculateDistanceMeters(lat, lng, nodeLat, nodeLng);

        places.add(TransportPlace(
          name: name,
          type: type,
          lat: nodeLat,
          lng: nodeLng,
          distanceMeters: dist,
        ));
      }

      places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return places;
    } catch (_) {
      return [];
    }
  }

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
        name.contains('bus stand')) {
      return 'Bus Complex';
    }
    if (highway == 'bus_stop' ||
        publicTransport == 'stop_position' ||
        publicTransport == 'platform') {
      return 'Bus Stop';
    }
    if (amenity == 'taxi' || amenity == 'auto_rickshaw' || name.contains('auto') || name.contains('taxi')) {
      return 'Auto Stand';
    }
    return null;
  }

  // ─── SUPABASE CACHE READ / WRITE ─────────────────────────────────────────────

  static Future<List<TransportPlace>?> _readCache(String key) async {
    try {
      final row = await _db
          .from('transport_cache')
          .select('transport_data, fetched_at')
          .eq('cache_key', key)
          .maybeSingle();

      if (row == null) return null;

      final fetchedAt = DateTime.parse(row['fetched_at'] as String);
      if (DateTime.now().difference(fetchedAt).inDays > _cacheExpiryDays) {
        return null; // Expired
      }

      final data = row['transport_data'] as List<dynamic>;
      return data
          .map((e) => TransportPlace.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(String key, List<TransportPlace> places) async {
    try {
      await Supabase.instance.client.from('transport_cache').upsert({
        'cache_key': key,
        'transport_data': places.map((p) => p.toJson()).toList(),
        'fetched_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── LOCAL SHAREDPREFS CACHE ─────────────────────────────────────────────────

  static const _localCachePrefix = 'transport_local_';

  static Future<List<TransportPlace>?> _readLocalCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_localCachePrefix$key');
      if (raw == null) return null;
      final Map<String, dynamic> stored = jsonDecode(raw);
      final savedAt = stored['saved_at'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - savedAt >
          _cacheExpiryDays * 24 * 60 * 60 * 1000) {
        return null;
      }
      final data = stored['data'] as List<dynamic>;
      return data.map((e) => TransportPlace.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeLocalCache(String key, List<TransportPlace> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'data': places.map((p) => p.toJson()).toList(),
      });
      await prefs.setString('$_localCachePrefix$key', payload);
    } catch (_) {}
  }
}
