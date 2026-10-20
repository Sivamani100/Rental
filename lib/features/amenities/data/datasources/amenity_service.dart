import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single nearby neighborhood essential / amenity with real coordinates and exact calculated distance
class AmenityPlace {
  final String name;
  final String category; // 'Healthcare', 'Education', 'Markets', 'Parks', 'Sports', 'Civic'
  final String type; // Card group: 'Hospitals & Medical', 'Schools & Colleges', 'Markets & Groceries', 'Parks & Nature', 'Sports & Grounds', 'Banks & Civic'
  final String subType; // 'Hospital', 'Clinic', 'Pharmacy', 'School', 'College', 'University', 'Supermarket', 'Marketplace', 'Park', 'Playground', 'Sports Centre', 'Bank', 'ATM', 'Police'
  final double lat;
  final double lng;
  final double distanceMeters;

  const AmenityPlace({
    required this.name,
    required this.category,
    required this.type,
    required this.subType,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Recalculates distance dynamically from the given origin coordinates
  AmenityPlace copyWithCalculatedDistance(double fromLat, double fromLng) {
    final dist = AmenityService.calculateDistanceMeters(fromLat, fromLng, lat, lng);
    return AmenityPlace(
      name: name,
      category: category,
      type: type,
      subType: subType,
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
        'category': category,
        'type': type,
        'subType': subType,
        'lat': lat,
        'lng': lng,
        'distanceMeters': distanceMeters,
      };

  factory AmenityPlace.fromJson(Map<String, dynamic> j) => AmenityPlace(
        name: j['name'] as String,
        category: (j['category'] as String?) ?? 'Essentials',
        type: j['type'] as String,
        subType: (j['subType'] as String?) ?? (j['type'] as String),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      );
}

class AmenityService {
  static final _db = Supabase.instance.client;

  // Cache expires after 14 days
  static const _cacheExpiryDays = 14;

  // Cache key version 2: ensures all old/stale Nominatim road or burial ground data is completely bypassed
  static String _cacheKey(double lat, double lng) =>
      'amenities_v2_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';

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

  /// Identifies and discards invalid, fake, graveyard, road, or generic mock entries
  static bool isInvalidPlace(String name, {String? osmClass, String? osmType}) {
    final lower = name.toLowerCase().trim();

    // 1. Minimum sanity check
    if (lower.isEmpty || lower.length < 3) return true;

    // 2. Reject cemeteries, burial grounds, crematoriums from being shown anywhere (especially sports grounds)
    if (lower.contains('burial') ||
        lower.contains('graveyard') ||
        lower.contains('cemetery') ||
        lower.contains('cremation') ||
        lower.contains('crematorium') ||
        lower.contains('smashan') ||
        lower.contains('rudrabhumi') ||
        lower.contains('kabristan') ||
        lower.contains('qabristan') ||
        lower.contains('tomb') ||
        osmType == 'grave_yard' ||
        osmType == 'cemetery') {
      return true;
    }

    // 3. Reject street/road names misidentified as amenities
    if (osmClass == 'highway' ||
        lower.endsWith(' road') ||
        lower.endsWith(' rd') ||
        lower.endsWith(' street') ||
        lower.endsWith(' lane') ||
        lower.endsWith(' highway') ||
        lower.endsWith(' bypass') ||
        lower.endsWith(' flyover') ||
        lower.contains(' feet rd') ||
        lower.startsWith('sh') && lower.contains('highway') ||
        lower.startsWith('nh ') ||
        lower.startsWith('sh ')) {
      return true;
    }

    // 4. Reject agricultural/farm plots from parks
    if (lower == 'coconut trees' ||
        lower.contains('plantation') ||
        lower.contains('paddy field') ||
        lower.contains('crop field')) {
      return true;
    }

    // 5. Reject generic single-word placeholders with zero identity
    if (lower == 'hospital' ||
        lower == 'clinic' ||
        lower == 'school' ||
        lower == 'college' ||
        lower == 'supermarket' ||
        lower == 'park' ||
        lower == 'garden' ||
        lower == 'bank' ||
        lower == 'atm' ||
        lower == 'ground' ||
        lower == 'general store-1' ||
        lower == 'test amenity' ||
        lower == 'sample') {
      return true;
    }

    // 6. Reject non-amenity OSM classes
    if (osmClass == 'boundary' ||
        osmClass == 'place' ||
        osmClass == 'waterway' ||
        osmClass == 'natural' && lower != 'park') {
      return true;
    }

    return false;
  }

  // ─── PUBLIC ENTRY POINT ─────────────────────────────────────────────────────

  static Future<List<AmenityPlace>> getNearby(double lat, double lng) async {
    final key = _cacheKey(lat, lng);

    // 1️⃣ Try Supabase cache first (shared across all users)
    final supabaseCached = await _readCache(key);
    if (supabaseCached != null && supabaseCached.isNotEmpty) {
      final hasFakes = supabaseCached.any((p) => isInvalidPlace(p.name));
      if (!hasFakes) {
        return supabaseCached
            .map((p) => p.copyWithCalculatedDistance(lat, lng))
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      }
    }

    // 2️⃣ Try local SharedPrefs cache
    final localCached = await _readLocalCache(key);
    if (localCached != null && localCached.isNotEmpty) {
      final hasFakes = localCached.any((p) => isInvalidPlace(p.name));
      if (!hasFakes) {
        return localCached
            .map((p) => p.copyWithCalculatedDistance(lat, lng))
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      }
    }

    // 3️⃣ Fetch real live neighborhood amenities from OpenStreetMap Nominatim, Photon & Overpass
    final fresh = await _fetchRealAmenities(lat, lng);

    // 4️⃣ Persist valid real results to both Supabase and local storage
    if (fresh.isNotEmpty) {
      _writeCache(key, fresh);
      _writeLocalCache(key, fresh);
    }

    return fresh;
  }

  // ─── REAL AMENITIES FETCHING ────────────────────────────────────────────────

  static Future<List<AmenityPlace>> _fetchRealAmenities(
      double lat, double lng) async {
    final List<AmenityPlace> allPlaces = [];
    final Set<String> seen = {};

    // Step A: Fetch real places via Nominatim with tight geographic delta and strict verification
    try {
      final nominatimResults = await _fetchFromNominatim(lat, lng);
      for (final p in nominatimResults) {
        final key = '${p.type}_${p.lat.toStringAsFixed(3)}_${p.lng.toStringAsFixed(3)}';
        if (!seen.contains(key) && !isInvalidPlace(p.name)) {
          seen.add(key);
          allPlaces.add(p);
        }
      }
    } catch (_) {}

    // Step B: Photon POI (Komoot OSM) fallback with strict validation if items are scarce
    if (allPlaces.length < 12) {
      try {
        final photonResults = await _fetchFromPhoton(lat, lng);
        for (final p in photonResults) {
          final key = '${p.type}_${p.lat.toStringAsFixed(3)}_${p.lng.toStringAsFixed(3)}';
          if (!seen.contains(key) && !isInvalidPlace(p.name)) {
            seen.add(key);
            allPlaces.add(p);
          }
        }
      } catch (_) {}
    }

    // Step C: Try Overpass for rich infrastructure nodes if still under target
    if (allPlaces.length < 15) {
      try {
        final overpassResults = await _fetchFromOverpass(lat, lng);
        for (final p in overpassResults) {
          final key = '${p.type}_${p.lat.toStringAsFixed(3)}_${p.lng.toStringAsFixed(3)}';
          if (!seen.contains(key) && !isInvalidPlace(p.name)) {
            seen.add(key);
            allPlaces.add(p);
          }
        }
      } catch (_) {}
    }

    // Sort strictly by exact distance
    allPlaces.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // Cap to at most 6 per category type
    final Map<String, int> shown = {};
    final List<AmenityPlace> filtered = [];
    for (final p in allPlaces) {
      if ((shown[p.type] ?? 0) < 6) {
        filtered.add(p);
        shown[p.type] = (shown[p.type] ?? 0) + 1;
      }
    }

    return filtered;
  }

  // ─── NOMINATIM POI FETCHER (LOCAL ACCURATE SEARCH) ──────────────────────────

  static Future<List<AmenityPlace>> _fetchFromNominatim(
      double lat, double lng) async {
    // Tight bounding boxes around the property ensuring only real nearby facilities are fetched
    final queries = [
      {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Hospital', 'q': 'hospital', 'delta': 0.08, 'maxDist': 12000.0, 'limit': 8},
      {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Clinic', 'q': 'clinic', 'delta': 0.04, 'maxDist': 5000.0, 'limit': 6},
      {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Pharmacy', 'q': 'pharmacy', 'delta': 0.03, 'maxDist': 3500.0, 'limit': 6},
      {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'School', 'q': 'school', 'delta': 0.05, 'maxDist': 6000.0, 'limit': 8},
      {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'College', 'q': 'college', 'delta': 0.08, 'maxDist': 12000.0, 'limit': 6},
      {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Supermarket', 'q': 'supermarket', 'delta': 0.05, 'maxDist': 6000.0, 'limit': 6},
      {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Rythu Bazar', 'q': 'rythu bazar', 'delta': 0.06, 'maxDist': 7000.0, 'limit': 4},
      {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Marketplace', 'q': 'bazar', 'delta': 0.04, 'maxDist': 5000.0, 'limit': 4},
      {'category': 'Parks', 'type': 'Parks & Nature', 'subType': 'Park', 'q': 'park', 'delta': 0.04, 'maxDist': 5000.0, 'limit': 6},
      {'category': 'Sports', 'type': 'Sports & Grounds', 'subType': 'Stadium', 'q': 'stadium', 'delta': 0.08, 'maxDist': 10000.0, 'limit': 4},
      {'category': 'Sports', 'type': 'Sports & Grounds', 'subType': 'Fitness Centre / Gym', 'q': 'fitness', 'delta': 0.04, 'maxDist': 5000.0, 'limit': 4},
      {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Bank', 'q': 'bank', 'delta': 0.04, 'maxDist': 5000.0, 'limit': 6},
      {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'ATM', 'q': 'atm', 'delta': 0.03, 'maxDist': 3500.0, 'limit': 6},
      {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Police Station', 'q': 'police station', 'delta': 0.06, 'maxDist': 8000.0, 'limit': 4},
    ];

    final headers = {
      'User-Agent': 'ArkioRentalApp/1.0 (Mobile; Flutter; VerifiedAmenities)',
      'Accept': 'application/json',
    };

    final fetched = await Future.wait(queries.map((q) async {
      final delta = q['delta'] as double;
      final category = q['category'] as String;
      final type = q['type'] as String;
      final subType = q['subType'] as String;
      final maxDist = q['maxDist'] as double;
      final limit = q['limit'] as int;
      final viewbox =
          '${lng - delta},${lat + delta},${lng + delta},${lat - delta}';
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q['q'] as String)}&format=json&viewbox=$viewbox&bounded=1&limit=$limit',
      );

      try {
        final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List<dynamic>;
          final List<AmenityPlace> places = [];
          for (final item in list) {
            final nodeLat = double.tryParse(item['lat']?.toString() ?? '');
            final nodeLng = double.tryParse(item['lon']?.toString() ?? '');
            if (nodeLat == null || nodeLng == null) continue;

            final osmClass = (item['class'] as String? ?? '').toLowerCase();
            final osmType = (item['type'] as String? ?? '').toLowerCase();

            // Use item name if available, otherwise display_name
            String rawName = (item['name'] as String? ?? '').trim();
            if (rawName.isEmpty) {
              final disp = (item['display_name'] as String? ?? '').trim();
              if (disp.isNotEmpty) {
                rawName = disp.split(',').first.trim();
              }
            }

            // Exclude invalid/road/cemetery entries
            if (isInvalidPlace(rawName, osmClass: osmClass, osmType: osmType)) {
              continue;
            }

            final dist = calculateDistanceMeters(lat, lng, nodeLat, nodeLng);
            if (dist > maxDist) continue;

            places.add(AmenityPlace(
              name: rawName,
              category: category,
              type: type,
              subType: subType,
              lat: nodeLat,
              lng: nodeLng,
              distanceMeters: dist,
            ));
          }
          return places;
        }
      } catch (_) {}
      return <AmenityPlace>[];
    }));

    return fetched.expand((x) => x).toList();
  }

  // ─── PHOTON POI FETCHER (KOMOOT OSM) ─────────────────────────────────────────

  static Future<List<AmenityPlace>> _fetchFromPhoton(
      double lat, double lng) async {
    final targets = [
      {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Hospital', 'q': 'hospital', 'maxDist': 12000.0},
      {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Clinic', 'q': 'clinic', 'maxDist': 5000.0},
      {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Pharmacy', 'q': 'pharmacy', 'maxDist': 3500.0},
      {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'School', 'q': 'school', 'maxDist': 6000.0},
      {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'College', 'q': 'college', 'maxDist': 12000.0},
      {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Supermarket', 'q': 'supermarket', 'maxDist': 6000.0},
      {'category': 'Parks', 'type': 'Parks & Nature', 'subType': 'Park', 'q': 'park', 'maxDist': 5000.0},
      {'category': 'Sports', 'type': 'Sports & Grounds', 'subType': 'Stadium', 'q': 'stadium', 'maxDist': 10000.0},
      {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Bank', 'q': 'bank', 'maxDist': 5000.0},
      {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Police Station', 'q': 'police station', 'maxDist': 8000.0},
    ];

    final headers = {'User-Agent': 'ArkioRentalApp/1.0 (Amenities)'};
    final results = await Future.wait(targets.map((t) async {
      final category = t['category'] as String;
      final type = t['type'] as String;
      final subType = t['subType'] as String;
      final q = t['q'] as String;
      final maxDist = t['maxDist'] as double;
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&lat=$lat&lon=$lng&limit=4',
      );

      try {
        final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final features = (data['features'] as List<dynamic>?) ?? [];
          final List<AmenityPlace> list = [];
          for (final f in features) {
            final props = (f['properties'] as Map<String, dynamic>?) ?? {};
            final coords = (f['geometry']?['coordinates'] as List<dynamic>?);
            if (coords == null || coords.length < 2) continue;

            final pLng = (coords[0] as num).toDouble();
            final pLat = (coords[1] as num).toDouble();

            final name = (props['name'] as String? ?? '').trim();
            final osmValue = (props['osm_value'] as String? ?? '').toLowerCase();

            if (isInvalidPlace(name, osmType: osmValue)) continue;

            final dist = calculateDistanceMeters(lat, lng, pLat, pLng);
            if (dist > maxDist) continue;

            list.add(AmenityPlace(
              name: name,
              category: category,
              type: type,
              subType: subType,
              lat: pLat,
              lng: pLng,
              distanceMeters: dist,
            ));
          }
          return list;
        }
      } catch (_) {}
      return <AmenityPlace>[];
    }));

    return results.expand((x) => x).toList();
  }

  // ─── OVERPASS API FETCHER (MULTI-MIRROR & FILTERED RADII) ────────────────────

  static const _overpassMirrors = [
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static Future<List<AmenityPlace>> _fetchFromOverpass(
      double lat, double lng) async {
    final query = '''
[out:json][timeout:8];
(
  node["amenity"="hospital"](around:8000,$lat,$lng);
  node["amenity"="clinic"](around:4000,$lat,$lng);
  node["amenity"="pharmacy"](around:3000,$lat,$lng);
  node["amenity"="school"](around:4000,$lat,$lng);
  node["amenity"="college"](around:10000,$lat,$lng);
  node["shop"="supermarket"](around:4000,$lat,$lng);
  node["amenity"="marketplace"](around:4000,$lat,$lng);
  node["leisure"="park"](around:4000,$lat,$lng);
  node["leisure"="pitch"](around:6000,$lat,$lng);
  node["leisure"="stadium"](around:10000,$lat,$lng);
  node["leisure"="fitness_centre"](around:4000,$lat,$lng);
  node["amenity"="bank"](around:3500,$lat,$lng);
  node["amenity"="atm"](around:2500,$lat,$lng);
  node["amenity"="police"](around:6000,$lat,$lng);
);
out center 40 tags;
''';

    final body = 'data=${Uri.encodeComponent(query)}';
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'ArkioRentalApp/1.0 (Flutter; Mobile; Amenities)',
    };

    for (final mirror in _overpassMirrors) {
      try {
        final response = await http
            .post(Uri.parse(mirror), body: body, headers: headers)
            .timeout(const Duration(seconds: 6));

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

  static List<AmenityPlace> _parseOverpassResponse(
      String body, double lat, double lng) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>?) ?? [];

      final List<AmenityPlace> places = [];
      final Set<String> seen = {};

      for (final el in elements) {
        final tags = (el['tags'] as Map<String, dynamic>?) ?? {};

        final double? nodeLat = (el['lat'] as num?)?.toDouble() ??
            ((el['center'] as Map<String, dynamic>?)?['lat'] as num?)?.toDouble();
        final double? nodeLng = (el['lon'] as num?)?.toDouble() ??
            ((el['center'] as Map<String, dynamic>?)?['lon'] as num?)?.toDouble();

        if (nodeLat == null || nodeLng == null) continue;

        final classification = _classifyAmenity(tags);
        if (classification == null) continue;

        String name = (tags['name'] as String? ??
                tags['name:en'] as String? ??
                tags['name:te'] as String? ??
                tags['brand'] as String? ??
                '')
            .trim();

        if (isInvalidPlace(name)) continue;

        final key =
            '${classification['type']}_${nodeLat.toStringAsFixed(3)}_${nodeLng.toStringAsFixed(3)}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final dist = calculateDistanceMeters(lat, lng, nodeLat, nodeLng);

        places.add(AmenityPlace(
          name: name,
          category: classification['category']!,
          type: classification['type']!,
          subType: classification['subType']!,
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

  static Map<String, String>? _classifyAmenity(Map<String, dynamic> tags) {
    final amenity = tags['amenity'] as String? ?? '';
    final shop = tags['shop'] as String? ?? '';
    final leisure = tags['leisure'] as String? ?? '';
    final name = (tags['name'] as String? ?? '').toLowerCase();

    // Reject grave/cemetery tags immediately
    if (amenity == 'grave_yard' || tags['landuse'] == 'cemetery') return null;

    // 1. Healthcare & Medical
    if (amenity == 'hospital' || name.contains('hospital')) {
      return {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Hospital'};
    }
    if (amenity == 'clinic' || amenity == 'doctors' || name.contains('clinic')) {
      return {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Clinic'};
    }
    if (amenity == 'pharmacy' || shop == 'chemist' || name.contains('pharmacy') || name.contains('medical')) {
      return {'category': 'Healthcare', 'type': 'Hospitals & Medical', 'subType': 'Pharmacy'};
    }

    // 2. Education & Institutions
    if (amenity == 'university' || name.contains('university')) {
      return {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'University'};
    }
    if (amenity == 'college' || name.contains('college') || name.contains('polytechnic')) {
      return {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'College'};
    }
    if (amenity == 'school' || amenity == 'kindergarten' || name.contains('school') || name.contains('vidyalaya')) {
      return {'category': 'Education', 'type': 'Schools & Colleges', 'subType': 'School'};
    }

    // 3. Markets & Groceries
    if (name.contains('rythu bazar') || name.contains('rythu bazaar')) {
      return {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Rythu Bazar'};
    }
    if (shop == 'supermarket' || shop == 'convenience' || name.contains('mart') || name.contains('supermarket')) {
      return {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Supermarket'};
    }
    if (amenity == 'marketplace' || shop == 'greengrocer' || name.contains('market') || name.contains('bazar')) {
      return {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Marketplace'};
    }
    if (shop == 'mall' || name.contains('mall')) {
      return {'category': 'Markets', 'type': 'Markets & Groceries', 'subType': 'Shopping Mall'};
    }

    // 4. Parks, Fitness & Nature
    if (leisure == 'park' || leisure == 'garden' || leisure == 'nature_reserve') {
      return {'category': 'Parks', 'type': 'Parks & Nature', 'subType': 'Park'};
    }
    if (leisure == 'playground' || name.contains('playground')) {
      return {'category': 'Parks', 'type': 'Parks & Nature', 'subType': 'Playground'};
    }

    // 5. Grounds, Sports & Stadiums
    if (leisure == 'stadium' || name.contains('stadium')) {
      return {'category': 'Sports', 'type': 'Sports & Grounds', 'subType': 'Stadium'};
    }
    if (leisure == 'pitch' || leisure == 'sports_centre' || name.contains('sports complex')) {
      return {'category': 'Sports', 'type': 'Sports & Grounds', 'subType': 'Sports Ground'};
    }
    if (leisure == 'fitness_centre' || name.contains('fitness') || name.contains('gym')) {
      return {'category': 'Sports', 'type': 'Sports & Grounds', 'subType': 'Fitness Centre / Gym'};
    }

    // 6. Civic & Banking
    if (amenity == 'atm' || name.contains('atm')) {
      return {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'ATM'};
    }
    if (amenity == 'bank' || name.contains('bank')) {
      return {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Bank'};
    }
    if (amenity == 'police' || name.contains('police')) {
      return {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Police Station'};
    }
    if (amenity == 'post_office' || name.contains('post office') || name.contains('meeseva')) {
      return {'category': 'Civic', 'type': 'Banks & Civic', 'subType': 'Civic Office'};
    }

    return null;
  }

  // ─── SUPABASE CACHE READ / WRITE ─────────────────────────────────────────────

  static Future<List<AmenityPlace>?> _readCache(String key) async {
    try {
      final row = await _db
          .from('amenities_cache')
          .select('amenities_data, fetched_at')
          .eq('cache_key', key)
          .maybeSingle();

      if (row == null) return null;

      final fetchedAt = DateTime.parse(row['fetched_at'] as String);
      if (DateTime.now().difference(fetchedAt).inDays > _cacheExpiryDays) {
        return null; // Expired
      }

      final data = row['amenities_data'] as List<dynamic>;
      return data
          .map((e) => AmenityPlace.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(String key, List<AmenityPlace> places) async {
    try {
      await Supabase.instance.client.from('amenities_cache').upsert({
        'cache_key': key,
        'amenities_data': places.map((p) => p.toJson()).toList(),
        'fetched_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── LOCAL SHAREDPREFS CACHE ─────────────────────────────────────────────────

  static const _localCachePrefix = 'amenities_local_v2_';

  static Future<List<AmenityPlace>?> _readLocalCache(String key) async {
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
      return data.map((e) => AmenityPlace.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeLocalCache(String key, List<AmenityPlace> places) async {
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
