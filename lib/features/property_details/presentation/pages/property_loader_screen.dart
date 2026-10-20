import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/app/theme/theme_provider.dart';
import 'package:rental/features/home/presentation/pages/home_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/property_details/presentation/utils/web_preloader.dart';
import 'package:rental/features/transport/data/datasources/transport_service.dart';

class PropertyLoaderScreen extends StatefulWidget {
  final String propertyId;
  final String? initialCachedPropertiesJson;

  const PropertyLoaderScreen({
    super.key,
    required this.propertyId,
    this.initialCachedPropertiesJson,
  });

  @override
  State<PropertyLoaderScreen> createState() => _PropertyLoaderScreenState();
}

class _PropertyLoaderScreenState extends State<PropertyLoaderScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _fetchPropertyAndNavigate();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchPropertyAndNavigate() async {
    final cleanId = widget.propertyId.trim();

    // 1. FAST PATH 1: Synchronous check in memory cachedPropertiesJson (0ms!)
    if (widget.initialCachedPropertiesJson != null &&
        widget.initialCachedPropertiesJson!.isNotEmpty) {
      try {
        final List list = jsonDecode(widget.initialCachedPropertiesJson!);
        final match = list.firstWhere(
          (item) => item['id'] == cleanId,
          orElse: () => null,
        );
        if (match != null && mounted) {
          final property = PropertyModel.fromJson(match);
          _navigateToDetails(property);
          return;
        }
      } catch (_) {}
    }

    // 2. FAST PATH 2: Check Web preloaded property from index.html (0ms on Web!)
    if (kIsWeb) {
      try {
        final webPropMap = findWebPreloadedProperty(cleanId);
        if (webPropMap != null && mounted) {
          final property = PropertyModel.fromJson(webPropMap);
          _navigateToDetails(property);
          return;
        }
      } catch (_) {}
    }

    try {
      // 3. FAST PATH 3: SharedPreferences cache check
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_properties');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List list = jsonDecode(cachedJson);
        final match = list.firstWhere(
          (item) => item['id'] == cleanId,
          orElse: () => null,
        );
        if (match != null && mounted) {
          final property = PropertyModel.fromJson(match);
          _navigateToDetails(property);
          return;
        }
      }

      // 4. Supabase fetch with 6-second timeout
      final res = await Supabase.instance.client
          .from('properties')
          .select()
          .eq('id', cleanId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (res != null && mounted) {
        final property = PropertyModel.fromJson(res);

        // Persist to local cache in background (unawaited so it never delays UI navigation)
        unawaited(Future(() async {
          try {
            final cJson = prefs.getString('cached_properties');
            List cList = cJson != null && cJson.isNotEmpty
                ? (jsonDecode(cJson) as List)
                : [];
            if (!cList.any((item) => item['id'] == property.id)) {
              cList.insert(0, res);
              await prefs.setString('cached_properties', jsonEncode(cList));
            }
          } catch (_) {}
        }));

        _navigateToDetails(property);
        return;
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Property listing not found or no longer active.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load property. Please check your connection.';
        });
      }
    }
  }

  void _navigateToDetails(PropertyModel property) {
    if (!mounted) return;
    final transportFuture = TransportService.getNearby(
      property.latitude,
      property.longitude,
    );
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PropertyDetailsScreen(
              property: property,
              preloadedTransportFuture: transportFuture,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              CupertinoIcons.back,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _handleBack,
          ),
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Arkio Rental',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.swiggyOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.swiggyOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? _buildSkeletonLoading(isDark)
            : _buildErrorState(isDark),
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    final placeholderColor = isDark
        ? const Color(0xFF1E222A)
        : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        final shimmerAlpha = _shimmerAnimation.value;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image Placeholder with Brand Badge
              Container(
                width: double.infinity,
                height: 230,
                decoration: BoxDecoration(
                  color: placeholderColor.withValues(alpha: shimmerAlpha),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_work_rounded,
                            size: 48,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.swiggyOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.swiggyOrange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Loading Property...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.swiggyOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Price Badge Shimmer
              Container(
                width: 140,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow.withValues(alpha: shimmerAlpha * 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 14),

              // Title Shimmer Lines
              Container(
                width: double.infinity,
                height: 24,
                decoration: BoxDecoration(
                  color: placeholderColor.withValues(alpha: shimmerAlpha),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 220,
                height: 24,
                decoration: BoxDecoration(
                  color: placeholderColor.withValues(alpha: shimmerAlpha),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              const SizedBox(height: 16),

              // Location Row Shimmer
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: placeholderColor.withValues(alpha: shimmerAlpha),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: placeholderColor.withValues(alpha: shimmerAlpha),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Highlights row (BHK, Baths, Area)
              Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: placeholderColor.withValues(alpha: shimmerAlpha * 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // Amenities placeholder row
              Container(
                width: 150,
                height: 18,
                decoration: BoxDecoration(
                  color: placeholderColor.withValues(alpha: shimmerAlpha),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 54,
                      margin: EdgeInsets.only(right: index < 3 ? 10 : 0),
                      decoration: BoxDecoration(
                        color: placeholderColor.withValues(alpha: shimmerAlpha * 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Property unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _fetchPropertyAndNavigate();
                  },
                  child: const Text('Try Again'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _handleBack,
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
