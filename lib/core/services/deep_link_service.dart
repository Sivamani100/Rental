import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:rental/features/property_details/presentation/pages/property_loader_screen.dart';

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

  // A global navigator key must be provided from main.dart to navigate when a link is tapped.
  GlobalKey<NavigatorState>? navigatorKey;

  void init(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    _appLinks = AppLinks();
    _handleIncomingLinks();
    _handleInitialLink();
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

  Future<void> _handleInitialLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
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
      _navigateToProperty(propertyId);
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

  void _navigateToProperty(String propertyId) {
    if (navigatorKey?.currentState == null) {
      _pendingPropertyId = propertyId;
      _startPendingRetry();
      return;
    }

    // Deduplicate rapid successive triggers for the same property
    final now = DateTime.now();
    if (_lastNavigatedPropertyId == propertyId &&
        _lastNavigatedTime != null &&
        now.difference(_lastNavigatedTime!).inMilliseconds < 1500) {
      debugPrint("[DeepLinkService] Skipping duplicate navigation for $propertyId");
      return;
    }

    _lastNavigatedPropertyId = propertyId;
    _lastNavigatedTime = now;
    _pendingPropertyId = null;
    _retryTimer?.cancel();

    debugPrint("[DeepLinkService] Pushing PropertyLoaderScreen for $propertyId");
    navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => PropertyLoaderScreen(propertyId: propertyId),
      ),
    );
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
    _retryTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      attempts++;
      if (navigatorKey?.currentState != null) {
        timer.cancel();
        if (_pendingPropertyId != null) {
          _navigateToProperty(_pendingPropertyId!);
        } else if (_pendingNamedRoute != null) {
          _navigateToNamed(_pendingNamedRoute!);
        }
      } else if (attempts >= 40) {
        // Stop after 4 seconds
        timer.cancel();
      }
    });
  }

  void dispose() {
    _retryTimer?.cancel();
    _linkSubscription?.cancel();
  }
}
