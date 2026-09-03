import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/app_snackbar.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import '../models/property_model.dart';
import '../screens/property_details_screen.dart';

class LocationPickerSheet extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final List<PropertyModel> properties;

  const LocationPickerSheet({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.properties = const [],
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late MapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = 'Move map to select location';
  bool _isDragging = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(widget.initialLatitude, widget.initialLongitude);
    _updateAddress(_currentCenter);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateAddress(LatLng pos) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final name = (place.subLocality != null && place.subLocality!.isNotEmpty) 
            ? place.subLocality 
            : (place.locality != null && place.locality!.isNotEmpty)
                ? place.locality
                : (place.name != null && place.name!.isNotEmpty)
                    ? place.name
                    : 'Unknown Location';
        if (mounted) {
          setState(() {
            _currentAddress = name!;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Unknown location';
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final locations = await Geocoding().locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPos = LatLng(loc.latitude, loc.longitude);
        _mapController.move(newPos, 15.0);
        setState(() {
          _currentCenter = newPos;
        });
        await _updateAddress(newPos);
      } else {
        if (mounted) AppSnackbar.error(context, 'Location not found');
      }
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to find location');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      // Padding for keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9, // 90% of screen height
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkScaffold : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: [
              // 1. Map as background
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: 15.0,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && position.center != null) {
                      setState(() {
                        _currentCenter = position.center!;
                        _isDragging = true;
                      });
                    }
                  },
                  onPointerUp: (event, point) {
                    setState(() {
                      _isDragging = false;
                    });
                    _updateAddress(_currentCenter);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.rental',
                    tileBuilder: (context, tileWidget, tile) {
                      if (!isDark) return tileWidget;
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -0.85, 0, 0, 0, 240,
                          0, -0.85, 0, 0, 240,
                          0, 0, -0.85, 0, 240,
                          0, 0, 0, 1, 0,
                        ]),
                        child: tileWidget,
                      );
                    },
                  ),
                  MarkerLayer(
                    markers: () {
                      final grouped = <String, List<PropertyModel>>{};
                      for (var prop in widget.properties) {
                        final key = '${prop.latitude.toStringAsFixed(4)},${prop.longitude.toStringAsFixed(4)}';
                        grouped.putIfAbsent(key, () => []).add(prop);
                      }

                      final allMarkers = <Marker>[];
                      grouped.forEach((key, group) {
                        for (int i = 0; i < group.length; i++) {
                          final property = group[i];
                          final type = property.type.toLowerCase();
                          Color markerColor = Colors.white;

                          if (type.contains('pg')) {
                            markerColor = Colors.red; // Changed from black/white to red based on user request
                          } else if (type.contains('rent') || type.contains('house')) {
                            markerColor = Colors.blueAccent;
                          } else if (type.contains('buy') || type.contains('sell') || type.contains('commercial')) {
                            markerColor = Colors.green;
                          } else {
                            markerColor = Colors.orangeAccent;
                          }

                          // If there are multiple properties at the exact same location, spread them in a tiny circle
                          double latOffset = 0;
                          double lngOffset = 0;
                          if (group.length > 1) {
                            final radius = 0.00015 * (group.length > 5 ? 2 : 1); // rough offset ~15 meters
                            final angle = (i * 2 * math.pi) / group.length;
                            latOffset = radius * math.cos(angle);
                            lngOffset = radius * math.sin(angle);
                          }
                          
                          allMarkers.add(
                            Marker(
                              point: LatLng(property.latitude + latOffset, property.longitude + lngOffset),
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // Close the bottom sheet
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PropertyDetailsScreen(property: property),
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.location_on, // Standard Google Maps style filled icon
                                  color: markerColor,
                                  size: 32,
                                ),
                              ),
                            ),
                          );
                        }
                      });
                      return allMarkers;
                    }(),
                  ),
                ],
              ),
              
              // 2. Center Pin marker
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40.0), // Offset for pin tip
                  child: AnimatedScale(
                    scale: _isDragging ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.location_on, // Swapped from Iconsax to normal pin
                      size: 40,
                      color: isDark ? Colors.white : Colors.black, // Distinct from property pins
                    ),
                  ),
                ),
              ),

              // 3. Floating UI Overlay
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section (Title + Search)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkScaffold : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Change Location',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Search by City/Area...',
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkCardElevated : Colors.white,
                            prefixIcon: Icon(Iconsax.search_normal, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(Iconsax.arrow_right_3, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 20),
                                    onPressed: () => _performSearch(_searchController.text),
                                  ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: _performSearch,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  
                  // Bottom Confirm Panel
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardElevated : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Iconsax.map_1, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Location',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentAddress,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: BouncingButton(
                            onTap: () {
                              // Return a Position object and Address text
                              final pos = Position(
                                latitude: _currentCenter.latitude,
                                longitude: _currentCenter.longitude,
                                timestamp: DateTime.now(),
                                accuracy: 1, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
                              );
                              Navigator.pop(context, {
                                'position': pos,
                                'address': _currentAddress,
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.primaryYellow : Colors.black,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Confirm Location',
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
