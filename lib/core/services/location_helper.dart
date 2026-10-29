import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationResult {
  final Position? position;
  final String city;
  final String area;
  final bool isPermissionDenied;

  const LocationResult({
    required this.position,
    required this.city,
    required this.area,
    this.isPermissionDenied = false,
  });
}

class LocationHelper {
  static const String defaultCity = 'Diwancheruvu';
  static const String defaultArea = 'Rajahmundry, India';

  static final Position defaultFallbackPosition = Position(
    latitude: 17.0440,
    longitude: 81.8430,
    timestamp: DateTime.now(),
    accuracy: 10,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );

  /// Requests location permission if not already granted and retrieves the current or last known position.
  static Future<LocationResult> fetchInitialLocation({
    Duration gpsTimeout = const Duration(seconds: 4),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCity = prefs.getString('cached_city');
      final cachedArea = prefs.getString('cached_area');
      final cachedLat = prefs.getDouble('cached_lat');
      final cachedLng = prefs.getDouble('cached_lng');

      Position? cachedPos;
      if (cachedLat != null && cachedLng != null) {
        cachedPos = Position(
          latitude: cachedLat,
          longitude: cachedLng,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      // 1. Check if location services are enabled on device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          position: cachedPos,
          city: cachedCity?.isNotEmpty == true ? cachedCity! : defaultCity,
          area: cachedArea?.isNotEmpty == true ? cachedArea! : defaultArea,
          isPermissionDenied: true,
        );
      }

      // 2. Check and request location permission FIRST THING
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return LocationResult(
          position: cachedPos,
          city: cachedCity?.isNotEmpty == true ? cachedCity! : defaultCity,
          area: cachedArea?.isNotEmpty == true ? cachedArea! : defaultArea,
          isPermissionDenied: true,
        );
      }

      // 3. Permission is GRANTED: Try last known position first (returns instantly <100ms)
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition()
            .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
      } catch (_) {}

      // 4. Concurrently or sequentially fetch accurate current position
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: gpsTimeout,
          ),
        ).timeout(gpsTimeout, onTimeout: () => position ?? cachedPos ?? defaultFallbackPosition);
        if (currentPos != null) {
          position = currentPos;
        }
      } catch (_) {}

      position ??= cachedPos;

      if (position != null) {
        // Cache coordinates
        try {
          await prefs.setDouble('cached_lat', position.latitude);
          await prefs.setDouble('cached_lng', position.longitude);
        } catch (_) {}

        // Reverse geocode to get real locality/city
        final geo = await reverseGeocode(position.latitude, position.longitude);
        final city = geo['city'] ?? cachedCity ?? defaultCity;
        final area = geo['area'] ?? cachedArea ?? defaultArea;

        try {
          await prefs.setString('cached_city', city);
          await prefs.setString('cached_area', area);
        } catch (_) {}

        return LocationResult(
          position: position,
          city: city,
          area: area,
          isPermissionDenied: false,
        );
      }

      // Fallback
      return LocationResult(
        position: cachedPos,
        city: cachedCity?.isNotEmpty == true ? cachedCity! : defaultCity,
        area: cachedArea?.isNotEmpty == true ? cachedArea! : defaultArea,
        isPermissionDenied: false,
      );
    } catch (e) {
      debugPrint('[LocationHelper] Error fetching location: $e');
      return LocationResult(
        position: null,
        city: defaultCity,
        area: defaultArea,
        isPermissionDenied: false,
      );
    }
  }

  /// High-reliability reverse geocode: Native Geocoding with OpenStreetMap & Photon HTTP fallback.
  static Future<Map<String, String>> reverseGeocode(double lat, double lng) async {
    // 1. Native OS geocoder
    try {
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => []);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
            ? p.subLocality!.trim()
            : (p.locality != null && p.locality!.trim().isNotEmpty)
                ? p.locality!.trim()
                : (p.name != null && p.name!.trim().isNotEmpty)
                    ? p.name!.trim()
                    : (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty)
                        ? p.subAdministrativeArea!.trim()
                        : (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty)
                            ? p.administrativeArea!.trim()
                            : '';

        final areaParts = <String>[];
        if (p.subAdministrativeArea != null &&
            p.subAdministrativeArea!.trim().isNotEmpty &&
            p.subAdministrativeArea != city) {
          areaParts.add(p.subAdministrativeArea!.trim());
        } else if (p.administrativeArea != null &&
            p.administrativeArea!.trim().isNotEmpty &&
            p.administrativeArea != city) {
          areaParts.add(p.administrativeArea!.trim());
        }
        if (p.country != null && p.country!.trim().isNotEmpty) {
          areaParts.add(p.country!.trim());
        }

        final area = areaParts.join(', ');
        if (city.isNotEmpty) {
          return {
            'city': city,
            'area': area.isNotEmpty ? area : 'India',
          };
        }
      }
    } catch (_) {}

    // 2. HTTP Fallback: OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=16&addressdetails=1',
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'RentalApp/1.0.0 (contact@rental.arkio.in)',
        'Accept': 'application/json',
      }).timeout(const Duration(milliseconds: 2500));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final city = (addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['city_district'] ??
                addr['residential'] ??
                addr['sublocality'] ??
                addr['village'] ??
                addr['town'] ??
                addr['city'] ??
                addr['county'] ??
                '')
            .toString()
            .trim();

        final parentCity = (addr['city'] ??
                addr['town'] ??
                addr['state_district'] ??
                addr['state'] ??
                'India')
            .toString()
            .trim();
        final state = (addr['state'] ?? 'India').toString().trim();
        final area = (parentCity.isNotEmpty && parentCity != city)
            ? '$parentCity, $state'
            : state;

        if (city.isNotEmpty) {
          return {'city': city, 'area': area};
        }
      }
    } catch (_) {}

    // 3. HTTP Fallback: Photon Komoot
    try {
      final url = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lng');
      final res = await http.get(url, headers: {
        'User-Agent': 'RentalApp/1.0.0 (contact@rental.arkio.in)',
      }).timeout(const Duration(milliseconds: 2000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final props =
              features.first['properties'] as Map<String, dynamic>? ?? {};
          final city = (props['district'] ??
                  props['name'] ??
                  props['city'] ??
                  props['town'] ??
                  '')
              .toString()
              .trim();
          final state =
              (props['state'] ?? props['country'] ?? 'India').toString().trim();
          if (city.isNotEmpty) {
            return {'city': city, 'area': state};
          }
        }
      }
    } catch (_) {}

    return {
      'city': defaultCity,
      'area': defaultArea,
    };
  }
}
