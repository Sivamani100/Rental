import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../app/theme/app_theme.dart';

class AreaCalculatorMapScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const AreaCalculatorMapScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  State<AreaCalculatorMapScreen> createState() => _AreaCalculatorMapScreenState();
}

class _AreaCalculatorMapScreenState extends State<AreaCalculatorMapScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _polygonPoints = [];
  final TextEditingController _searchController = TextEditingController();
  
  double _calculatedAreaSqft = 0.0;
  bool _isSearching = false;

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _calculateArea();
    });
  }
  
  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _calculateArea();
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _polygonPoints.clear();
      _calculatedAreaSqft = 0.0;
    });
  }

  void _calculateArea() {
    if (_polygonPoints.length < 3) {
      _calculatedAreaSqft = 0.0;
      return;
    }
    
    const double R = 6378137; // Earth's radius in meters
    List<math.Point<double>> points = [];
    double meanLat = 0;
    for (var c in _polygonPoints) {
      meanLat += c.latitude;
    }
    meanLat = (meanLat / _polygonPoints.length) * (math.pi / 180.0);
    
    for (var c in _polygonPoints) {
      double x = R * (c.longitude * math.pi / 180.0) * math.cos(meanLat);
      double y = R * (c.latitude * math.pi / 180.0);
      points.add(math.Point(x, y));
    }
    
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += points[i].x * points[j].y;
      area -= points[j].x * points[i].y;
    }
    
    double areaSqm = area.abs() / 2.0;
    _calculatedAreaSqft = areaSqm * 10.7639104; // convert to sqft
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'rentalecosystem_app'
      });
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          _mapController.move(LatLng(lat, lon), 18.0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching location.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculate Area', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.primaryYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.check, size: 28),
            color: isDark ? AppTheme.primaryYellow : Colors.black,
            onPressed: () {
              Navigator.pop(context, _calculatedAreaSqft.round().toString());
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation ?? const LatLng(17.6868, 83.2185), // Default to Visakhapatnam
              initialZoom: 18.0,
              maxZoom: 22.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.rental',
                maxNativeZoom: 21,
                maxZoom: 22.0,
              ),
              if (_polygonPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon<Object>(
                      points: _polygonPoints,
                      color: isDark ? AppTheme.primaryYellow.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                      borderColor: isDark ? AppTheme.primaryYellow : Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _polygonPoints.map((p) {
                  return Marker(
                    point: p,
                    width: 12,
                    height: 12,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // Search Bar
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardElevated : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search village, street or city...',
                        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                  _isSearching 
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        icon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: _searchLocation,
                      ),
                ],
              ),
            ),
          ),
          
          // Bottom Panel
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardElevated : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Area',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo_rounded, size: 24),
                            color: isDark ? Colors.white70 : Colors.black87,
                            onPressed: _undoLastPoint,
                            tooltip: 'Undo last point',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 24),
                            color: Colors.redAccent,
                            onPressed: _clearPoints,
                            tooltip: 'Clear all points',
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_calculatedAreaSqft.round()} sqft',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap corners of the property on the map to calculate its area.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontFamily: 'SF Pro Display',
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
