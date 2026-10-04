import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String title;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
    });
  }

  void _centerOnMyLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    } else {
      _getCurrentLocation().then((_) {
        if (_currentPosition != null) {
          _mapController.move(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            16.0,
          );
        } else {
          if (mounted) {
            AppSnackbar.error(context, 'Location not available');
          }
        }
      });
    }
  }

  Future<void> _startDirections(BuildContext context) async {
    final double lat = widget.latitude;
    final double lng = widget.longitude;

    Uri uri;

    // Use native navigation schemes for Android and iOS when not on Web
    if (!kIsWeb && Platform.isAndroid) {
      // google.navigation scheme forces Google Maps into Turn-by-Turn navigation
      uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    } else if (!kIsWeb && Platform.isIOS) {
      // Apple Maps directions scheme
      uri = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    } else {
      // Fallback to web directions (opens in browser)
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to general web URL if native schemes fail
        final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else if (context.mounted) {
          AppSnackbar.error(context, 'Could not open maps application');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, 'Could not open maps application');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(CupertinoIcons.chevron_left, color: isDark ? Colors.white : Colors.black, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.latitude, widget.longitude),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.arkiolabs.rental',
                maxNativeZoom: 21,
                maxZoom: 22.0,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitude, widget.longitude),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2330) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: const Icon(CupertinoIcons.location_solid, color: Colors.red, size: 36),
                    ),
                  ),
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                )
                              ]
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BouncingButton(
                    onTap: _centerOnMyLocation,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2330) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Iconsax.gps,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: BouncingButton(
                      scaleFactor: 0.96,
                      onTap: () => _startDirections(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.primaryYellow : Colors.black,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_swap,
                              color: isDark ? Colors.black : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Get Directions',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
