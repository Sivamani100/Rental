import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_loader_screen.dart';
import 'package:rental/features/transport/data/datasources/transport_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _retryTimer;
  String? _pendingPropertyId;
  String? _pendingNamedRoute;

  String? _lastNavigatedPropertyId;
  DateTime? _lastNavigatedTime;
  bool _isNavigating = false;
  bool isHandlingDeepLink = false;

  // A global navigator key must be provided from main.dart to navigate when a link is tapped.
  GlobalKey<NavigatorState>? navigatorKey;

  void init(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    _appLinks = AppLinks();
    _handleIncomingLinks();
    if (!kIsWeb) {
      _handleInitialLink();
    }
  }

  /// Extracts propertyId from ANY deep link format:
  /// - https://rental.arkio.in/property/:id
  /// - https://rental.arkio.in/?propertyId=:id
  /// - https://rental.arkio.in/?id=:id
  /// - rental://property/:id
  /// - rental://property?propertyId=:id or ?id=:id
  /// - rental://rental.arkio.in/property/:id
  /// - arkio://rental/property/:id or ?propertyId=:id
  static String? extractPropertyId(Uri uri) {
    // 1. Check query parameters first
    final queryId = uri.queryParameters['propertyId'] ??
        uri.queryParameters['id'] ??
        uri.queryParameters['property_id'];
    if (queryId != null && queryId.trim().isNotEmpty) {
      return queryId.trim();
    }

    // 2. Check path segments (e.g. /property/abc or /p/abc or /listing/abc)
    final segments = uri.pathSegments;
    final propIndex = segments.indexWhere((s) {
      final lower = s.toLowerCase();
      return lower == 'property' || lower == 'p' || lower == 'listing';
    });
    if (propIndex != -1 && propIndex + 1 < segments.length) {
      final segId = segments[propIndex + 1].trim();
      if (segId.isNotEmpty) return segId;
    }

    // 3. Check custom scheme host (e.g. rental://property/abc or rental://property)
    if (uri.host.toLowerCase() == 'property' && segments.isNotEmpty) {
      final segId = segments.first.trim();
      if (segId.isNotEmpty) return segId;
    }

    // 4. Fallback: string matching on raw path
    final rawPath = uri.path.toLowerCase();
    if (rawPath.contains('/property/')) {
      final after = uri.path.substring(rawPath.indexOf('/property/') + 10);
      final clean = after.split('/').first.split('?').first.trim();
      if (clean.isNotEmpty) return clean;
    }

    return null;
  }

  /// Manually marks a property as navigated so background AppLink listeners don't double-navigate.
  void markAsNavigated(String propertyId) {
    _lastNavigatedPropertyId = propertyId.trim();
    _lastNavigatedTime = DateTime.now();
  }

  /// Fast synchronous lookup in the cached properties JSON string.
  static PropertyModel? findCachedProperty(String propertyId, String? cachedJson) {
    if (cachedJson == null || cachedJson.isEmpty) return null;
    try {
      final clean = propertyId.trim();
      final List list = jsonDecode(cachedJson);
      final match = list.firstWhere(
        (item) => item['id'] == clean,
        orElse: () => null,
      );
      if (match != null) {
        return PropertyModel.fromJson(match);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleInitialLink() async {
    try {
      Uri? initialLink;
      if (kIsWeb) {
        initialLink = Uri.base;
      } else {
        initialLink = await _appLinks.getInitialLink();
      }
      if (initialLink != null) {
        debugPrint("[DeepLinkService] Found initial deep link: $initialLink");
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint("[DeepLinkService] Failed to get initial deep link: $e");
    }
  }

  void _handleIncomingLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        debugPrint("[DeepLinkService] Received incoming deep link: $uri");
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("[DeepLinkService] Deep link error: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    // 1. Try extracting property ID
    final propertyId = extractPropertyId(uri);
    if (propertyId != null && propertyId.isNotEmpty) {
      navigateToProperty(propertyId);
      return;
    }

    // 2. Check for assistant / AI routes
    final path = uri.path.toLowerCase();
    if (path == '/ai' || path == '/ai-chat' || path == '/assistant') {
      _navigateToNamed(path);
      return;
    }

    // 3. Fallback: only if it's explicitly a home or empty request
    if (path == '/' || path.isEmpty) {
      // Do not reset the user's stack if they're already on a screen
      return;
    }
  }

  void navigateToProperty(String propertyId) async {
    final cleanId = propertyId.trim();
    if (cleanId.isEmpty) return;

    // Strong deduplication: 5 seconds and mutex flag
    final now = DateTime.now();
    if (_isNavigating) return;
    if (_lastNavigatedPropertyId == cleanId &&
        _lastNavigatedTime != null &&
        now.difference(_lastNavigatedTime!).inMilliseconds < 5000) {
      debugPrint("[DeepLinkService] Skipping duplicate navigation for $cleanId");
      return;
    }

    isHandlingDeepLink = true;

    if (navigatorKey?.currentState == null) {
      _pendingPropertyId = cleanId;
      _startPendingRetry();
      return;
    }

    _lastNavigatedPropertyId = cleanId;
    _lastNavigatedTime = now;
    _pendingPropertyId = null;
    _retryTimer?.cancel();
    _isNavigating = true;

    try {
      // 1. FAST PATH: Check SharedPreferences cached_properties for instant 0ms load!
      PropertyModel? cachedProperty;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('cached_properties');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final List list = jsonDecode(cachedJson);
          final match = list.firstWhere(
            (item) => item['id'] == cleanId,
            orElse: () => null,
          );
          if (match != null) {
            cachedProperty = PropertyModel.fromJson(match);
          }
        }
      } catch (_) {}

      if (cachedProperty != null && navigatorKey?.currentState != null) {
        debugPrint("[DeepLinkService] Instant cache hit for $cleanId — opening PropertyDetails directly");
        final transportFuture = TransportService.getNearby(
          cachedProperty.latitude,
          cachedProperty.longitude,
        );
        navigatorKey!.currentState!.push(
          MaterialPageRoute(
            builder: (_) => PropertyDetailsScreen(
              property: cachedProperty!,
              preloadedTransportFuture: transportFuture,
            ),
          ),
        );
        return;
      }

      // 2. If not in cache, push PropertyLoaderScreen to fetch from Supabase
      debugPrint("[DeepLinkService] Pushing PropertyLoaderScreen for $cleanId");
      navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => PropertyLoaderScreen(propertyId: cleanId),
        ),
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _isNavigating = false;
      });
    }
  }

  void _navigateToNamed(String routeName) {
    if (navigatorKey?.currentState == null) {
      _pendingNamedRoute = routeName;
      _startPendingRetry();
      return;
    }

    _pendingNamedRoute = null;
    _retryTimer?.cancel();
    navigatorKey!.currentState!.pushNamed(routeName);
  }

  void _startPendingRetry() {
    _retryTimer?.cancel();
    int attempts = 0;
    _retryTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      attempts++;
      if (navigatorKey?.currentState != null) {
        timer.cancel();
        if (_pendingPropertyId != null) {
          final id = _pendingPropertyId!;
          _pendingPropertyId = null;
          navigateToProperty(id);
        } else if (_pendingNamedRoute != null) {
          _navigateToNamed(_pendingNamedRoute!);
        }
      } else if (attempts >= 60) {
        // Stop after 3 seconds
        timer.cancel();
      }
    });
  }

  void dispose() {
    _retryTimer?.cancel();
    _linkSubscription?.cancel();
  }
}
