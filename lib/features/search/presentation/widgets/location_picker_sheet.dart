import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';

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
  Timer? _debounce;
  List<dynamic> _suggestions = [];


  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(widget.initialLatitude, widget.initialLongitude);
    _updateAddress(_currentCenter);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateAddress(LatLng pos) async {
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=jsonv2&addressdetails=1'),
        headers: {'User-Agent': 'RentalEcoApp/1.0 (mallipurapusiva@gmail.com)'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final name = data['display_name'];
        if (name != null && mounted) {
          setState(() {
            _currentAddress = name;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocode error: $e');
    }
    if (mounted) {
      setState(() {
        _currentAddress = 'Unknown location';
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=jsonv2&addressdetails=1&countrycodes=in&limit=8'),
        headers: {'User-Agent': 'RentalEcoApp/1.0 (mallipurapusiva@gmail.com)'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _suggestions = data;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query);
    });
  }

  void _onSuggestionSelected(dynamic suggestion) {
    final lat = double.tryParse(suggestion['lat'].toString()) ?? 0.0;
    final lon = double.tryParse(suggestion['lon'].toString()) ?? 0.0;
    final name = suggestion['display_name'] ?? 'Unknown Location';
    
    final newPos = LatLng(lat, lon);
    _mapController.move(newPos, 15.0);
    setState(() {
      _currentCenter = newPos;
      _currentAddress = name;
      _suggestions = [];
      _searchController.text = name.split(',').first;
    });
    FocusScope.of(context).unfocus();
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
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 16.0,
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
                          final key = ',';
                          grouped.putIfAbsent(key, () => []).add(prop);
                        }

                        final allMarkers = <Marker>[];
                        grouped.forEach((key, group) {
                          for (int i = 0; i < group.length; i++) {
                            final property = group[i];
                            final type = property.type.toLowerCase();
                            Color markerColor = Colors.white;

                            if (type.contains('pg') || type.contains('hostel')) {
                              markerColor = Colors.red;
                            } else if (type.contains('rent') || type.contains('house')) {
                              markerColor = Colors.blueAccent;
                            } else if (type.contains('buy') || type.contains('sell') || type.contains('commercial')) {
                              markerColor = Colors.green;
                            } else {
                              markerColor = Colors.orangeAccent;
                            }

                            double latOffset = 0;
                            double lngOffset = 0;
                            if (group.length > 1) {
                              final radius = 0.00015 * (group.length > 5 ? 2 : 1);
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
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PropertyDetailsScreen(property: property),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    CupertinoIcons.location_solid,
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
              ),
              
              // 2. Center Pin marker (shifted slightly up to account for bottom panel)
              Align(
                alignment: const Alignment(0, -0.25),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 42.0), // Offset for pin tip
                  child: AnimatedScale(
                    scale: _isDragging ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                            ]
                          ),
                          child: const Icon(
                            CupertinoIcons.location_solid, 
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        // The pin stick/shadow
                        Container(
                          width: 2,
                          height: 16,
                          color: Colors.black,
                        ),
                        Container(
                          width: 6,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)]
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Floating Top Search Bar
              Positioned(
                top: 24,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardElevated : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08), 
                            blurRadius: 12, 
                            offset: const Offset(0, 4)
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontFamily: 'ProximaNova',
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search area, street name...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey.shade500, 
                            fontSize: 15,
                            fontFamily: 'ProximaNova',
                          ),
                          prefixIcon: IconButton(
                            icon: Icon(CupertinoIcons.back, color: isDark ? Colors.white : Colors.black87),
                            onPressed: () => Navigator.pop(context),
                          ),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  ),
                                )
                              : _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(CupertinoIcons.clear_circled_solid, color: Colors.grey.shade400, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _suggestions = []);
                                      },
                                    )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onSubmitted: _performSearch,
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardElevated : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _suggestions.length,
                          separatorBuilder: (c, i) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade100),
                          itemBuilder: (c, i) {
                            final suggestion = _suggestions[i];
                            final parts = (suggestion['display_name'] ?? '').split(',');
                            final title = parts.isNotEmpty ? parts[0] : '';
                            final subtitle = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
                            return ListTile(
                              leading: Icon(CupertinoIcons.location_solid, color: Colors.grey.shade400, size: 20),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15, 
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'DMSans',
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: subtitle.isNotEmpty 
                                  ? Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'ProximaNova',
                                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => _onSuggestionSelected(suggestion),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Floating Locate Me button
              Positioned(
                bottom: 230, // Above the bottom panel
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: isDark ? AppTheme.darkCardElevated : Colors.white,
                  child: Icon(Icons.my_location, color: isDark ? Colors.white : Colors.black87),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    try {
                      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                      final newPos = LatLng(pos.latitude, pos.longitude);
                      _mapController.move(newPos, 16.0);
                      setState(() {
                        _currentCenter = newPos;
                        _suggestions = [];
                        _searchController.clear();
                      });
                      await _updateAddress(newPos);
                    } catch (_) {
                      if (mounted) AppSnackbar.error(context, 'Could not get current location');
                    }
                  },
                ),
              ),

              // 5. Bottom Confirm Panel (Swiggy style)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkScaffold : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                          fontFamily: 'ProximaNova',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.location_solid, 
                            color: isDark ? Colors.white : Colors.black, 
                            size: 26
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentAddress.split(',').first, // Title
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'DMSans',
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentAddress, // Full Address
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'ProximaNova',
                                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: BouncingButton(
                          onTap: () {
                            final pos = Position(
                              latitude: _currentCenter.latitude,
                              longitude: _currentCenter.longitude,
                              timestamp: DateTime.now(),
                              accuracy: 1, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
                            );
                            Navigator.pop(context, {
                              'position': pos,
                              'address': _currentAddress.split(',').first,
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Confirm Location',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 16,
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.w800,
                              ),
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
        ),
      ),
    );
  }
}
