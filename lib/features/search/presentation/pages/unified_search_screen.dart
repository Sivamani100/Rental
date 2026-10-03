import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';

// Top-level isolate helper for JSON parsing
List<PropertyModel> _parsePropertiesIsolate(String jsonStr) {
  final decoded = jsonDecode(jsonStr) as List;
  return decoded
      .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  String _searchQuery = '';
  Timer? _searchDebounce;
  
  List<dynamic> _locationSuggestions = [];
  bool _isSearchingLocations = false;
  
  List<PropertyModel> _allProperties = [];
  bool _isLoadingProperties = true;

  @override
  void initState() {
    super.initState();
    _loadCachedProperties();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_properties');
      if (cachedData != null && cachedData.isNotEmpty) {
        final cachedList = await compute(_parsePropertiesIsolate, cachedData);
        if (mounted) {
          setState(() {
            _allProperties = cachedList;
            _isLoadingProperties = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingProperties = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProperties = false);
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (val.trim().isNotEmpty) {
        _fetchLocationSuggestions(val);
      } else {
        if (mounted) setState(() { _locationSuggestions = []; });
      }
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    setState(() { _isSearchingLocations = true; });
    try {
      final url = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RentalApp/1.0.0 (contact@rental.arkio.in)',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null) {
          if (mounted) setState(() { _locationSuggestions = List.from(data['features']); });
        }
      }
    } catch (_) {}
    if (mounted) setState(() { _isSearchingLocations = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 15.5,
                color: isDark ? Colors.white : Colors.grey.shade900,
                fontWeight: FontWeight.w500,
              ),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search properties or locations...",
                hintStyle: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 15.0,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Icon(
                    CupertinoIcons.search,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(CupertinoIcons.clear, color: isDark ? Colors.grey.shade400 : Colors.black54, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : IconButton(
                        icon: Icon(CupertinoIcons.mic_fill, color: isDark ? Colors.grey.shade400 : Colors.black54, size: 20),
                        onPressed: () {}, // Future Voice feature
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_searchQuery.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.search, size: 64, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Type to search",
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    
    final query = _searchQuery.toLowerCase();
    final matchedProperties = _allProperties.where((p) => 
        p.title.toLowerCase().contains(query) || 
        p.locationStr.toLowerCase().contains(query)).take(10).toList();
        
    final hasNoResults = matchedProperties.isEmpty && _locationSuggestions.isEmpty && !_isSearchingLocations;
    
    if (hasNoResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 64, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No exact matches found",
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try searching for a different property or village.",
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (matchedProperties.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
            child: Text(
              'PROPERTIES', 
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 12, 
                fontWeight: FontWeight.w700, 
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...matchedProperties.map((p) => Container(
            color: isDark ? AppTheme.darkScaffold : Colors.white,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(CupertinoIcons.building_2_fill, color: AppTheme.primaryYellow, size: 20),
              ),
              title: Text(
                p.title, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis, 
                style: TextStyle(fontFamily: 'ProximaNova', fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)
              ),
              subtitle: Text(
                p.locationStr, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis, 
                style: TextStyle(fontFamily: 'ProximaNova', fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.black54)
              ),
              onTap: () {
                _searchFocusNode.unfocus();
                Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: p)));
              },
            ),
          )),
        ],
        
        if (_locationSuggestions.isNotEmpty || _isSearchingLocations) ...[
          if (matchedProperties.isNotEmpty) 
            const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
            child: Text(
              'VILLAGES & CITIES', 
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 12, 
                fontWeight: FontWeight.w700, 
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          if (_isSearchingLocations)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            ..._locationSuggestions.map((feature) {
              final props = feature['properties'] ?? {};
              final name = props['name'] ?? '';
              final state = props['state'] ?? '';
              final county = props['county'] ?? '';
              
              final subtitleParts = [county, state].where((e) => e.toString().trim().isNotEmpty).toList();
              final subtitle = subtitleParts.join(', ');
              
              return Container(
                color: isDark ? AppTheme.darkScaffold : Colors.white,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(CupertinoIcons.location_solid, color: isDark ? Colors.grey.shade300 : Colors.black54, size: 20),
                  ),
                  title: Text(
                    name.isEmpty ? 'Unknown Location' : name, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: TextStyle(fontFamily: 'ProximaNova', fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)
                  ),
                  subtitle: Text(
                    subtitle, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: TextStyle(fontFamily: 'ProximaNova', fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.black54)
                  ),
                  onTap: () {
                    _searchFocusNode.unfocus();
                    final geometry = feature['geometry'] ?? {};
                    final coords = geometry['coordinates'] as List?;
                    if (coords != null && coords.length >= 2) {
                      final lon = (coords[0] as num).toDouble();
                      final lat = (coords[1] as num).toDouble();
                      
                      final newPos = Position(
                        latitude: lat,
                        longitude: lon,
                        timestamp: DateTime.now(),
                        accuracy: 1, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
                      );
                      Navigator.pop(context, newPos);
                    }
                  },
                ),
              );
            }),
        ],
      ],
    );
  }
}
