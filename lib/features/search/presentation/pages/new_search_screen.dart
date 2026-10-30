import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/partner/data/models/partner_promotion_model.dart';
import 'package:rental/features/search/presentation/widgets/new_search_bar.dart';
import 'package:rental/features/search/presentation/pages/voice_search_screen.dart';
import 'package:rental/app/theme/app_theme.dart';

class NewSearchScreen extends StatefulWidget {
  final List<PropertyModel>? initialProperties;
  final String? initialQuery;
  final String? initialCategory;
  final Position? currentPosition;

  const NewSearchScreen({
    super.key,
    this.initialProperties,
    this.initialQuery,
    this.initialCategory,
    this.currentPosition,
  });

  @override
  State<NewSearchScreen> createState() => _NewSearchScreenState();
}

class _NewSearchScreenState extends State<NewSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  Timer? _searchDebounce;

  List<PropertyModel> _allProperties = [];
  List<String> _recentSearches = [];
  List<dynamic> _locationSuggestions = [];
  bool _isSearchingLocations = false;

  final _supabase = Supabase.instance.client;
  Map<String, PartnerPromotionModel> _activePromotions = {};

  static const List<String> _defaultRecentSearches = [
    'Diwancheruvu',
    'Boys Hostel',
    '2 BHK Flat',
    'Rajahmundry',
    'Furnished Rentals',
    'Girls PG',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialProperties != null && widget.initialProperties!.isNotEmpty) {
      _allProperties = List.from(widget.initialProperties!);
    } else {
      _loadCachedProperties();
    }

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onSearchChanged(widget.initialQuery!);
        }
      });
    }

    _loadRecentSearches();
    _fetchActivePromotions();

    // Smooth focus after transition to avoid frame drops
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
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
        final decoded = jsonDecode(cachedData) as List;
        final list = decoded
            .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _allProperties = list;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('recent_searches');
      if (stored != null && stored.isNotEmpty) {
        if (mounted) setState(() => _recentSearches = stored);
      } else {
        if (mounted) setState(() => _recentSearches = List.from(_defaultRecentSearches));
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(_recentSearches);
      list.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
      list.insert(0, clean);
      if (list.length > 8) {
        list.removeRange(8, list.length);
      }
      await prefs.setStringList('recent_searches', list);
      if (mounted) setState(() => _recentSearches = list);
    } catch (_) {}
  }

  Future<void> _fetchActivePromotions() async {
    try {
      final res = await _supabase
          .from('property_promotions')
          .select()
          .or('status.eq.approved,status.eq.active');
      final Map<String, PartnerPromotionModel> map = {};
      for (var row in (res as List)) {
        final promo = PartnerPromotionModel.fromJson(Map<String, dynamic>.from(row));
        if (promo.isActive && promo.propertyId.isNotEmpty) {
          map[promo.propertyId] = promo;
        }
      }
      if (mounted) {
        setState(() {
          _activePromotions = map;
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (val.trim().isNotEmpty) {
        _fetchLocationSuggestions(val);
      } else {
        if (mounted) {
          setState(() {
            _locationSuggestions = [];
            _isSearchingLocations = false;
          });
        }
      }
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    setState(() => _isSearchingLocations = true);
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RentalApp/1.0.0 (contact@rental.arkio.in)',
        },
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && mounted) {
          setState(() {
            _locationSuggestions = List.from(data['features']);
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearchingLocations = false);
  }

  bool _matchesQuery(PropertyModel p, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();

    // Check title, location, type, tags, features, description
    if (p.title.toLowerCase().contains(q)) return true;
    if (p.locationStr.toLowerCase().contains(q)) return true;
    if (p.type.toLowerCase().contains(q)) return true;
    if (p.bhkType != null && p.bhkType!.toLowerCase().contains(q)) return true;
    if (p.tags.any((t) => t.toLowerCase().contains(q))) return true;
    if (p.features.any((f) => f.toLowerCase().contains(q))) return true;
    if (p.description != null && p.description!.toLowerCase().contains(q)) return true;

    // Special keywords
    if (q == 'hostel' || q == 'hostels' || q == 'pg' || q == 'hostel & pg' || q == 'hostels & pg') {
      final t = p.type.toLowerCase();
      final title = p.title.toLowerCase();
      return t.contains('pg') ||
          t.contains('hostel') ||
          title.contains('pg') ||
          title.contains('hostel') ||
          title.contains('guest house') ||
          title.contains('dormitory') ||
          p.tags.any((tag) => tag.toLowerCase().contains('pg') || tag.toLowerCase().contains('hostel')) ||
          (p.sharingType != null && p.sharingType!.isNotEmpty);
    }
    if (q.contains('bhk')) {
      return p.title.toLowerCase().contains(q) ||
          (p.bhkType != null && p.bhkType!.toLowerCase().contains(q));
    }

    return false;
  }

  List<PropertyModel> _getFilteredProperties() {
    var list = _allProperties.where((p) => _matchesQuery(p, _searchQuery)).toList();

    // Sort by proximity if position is available
    final pos = widget.currentPosition;
    if (pos != null) {
      list.sort((a, b) {
        final distA = Geolocator.distanceBetween(pos.latitude, pos.longitude, a.latitude, a.longitude);
        final distB = Geolocator.distanceBetween(pos.latitude, pos.longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    }

    return list;
  }

  void _applySearchQuery(String query) {
    HapticFeedback.selectionClick();
    _saveRecentSearch(query);
    _searchController.text = query;
    _searchQuery = query;
    _onSearchChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTyping = _searchQuery.trim().isNotEmpty;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isTyping ? surfaceColor : Colors.transparent, // Solid surface when searching, transparent when idle!
        body: Column(
          children: [
            // ── Top White Sheet (with rounded bottom when idle) ──
            GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(isTyping ? 0 : 32),
                    bottomRight: Radius.circular(isTyping ? 0 : 32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: isTyping ? 0 : 18,
                      spreadRadius: isTyping ? 0 : 2,
                      offset: Offset(0, isTyping ? 0 : 6),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top App Bar (Back Arrow + Title)
                      _buildTopHeader(isDark),

                      // 2. Swiggy-Style Search Bar Box
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        child: NewSearchBar(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          readOnly: false,
                          autofocus: true,
                          onChanged: _onSearchChanged,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _saveRecentSearch(val);
                            }
                          },
                          onClear: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          onVoiceTap: () async {
                            HapticFeedback.selectionClick();
                            final result = await VoiceSearchScreen.open(
                              context,
                              properties: _allProperties,
                            );
                            if (result != null && result.trim().isNotEmpty) {
                              _searchController.text = result.trim();
                              _onSearchChanged(result.trim());
                            }
                          },
                        ),
                      ),

                      // 3. Recently Searched Properties (Only shown when not typing)
                      if (!isTyping) ...[
                        _buildRecentSearchesSection(isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Area below Top Sheet ─────────────────────────────────
            // When TYPING: Full-height solid surface with suggestions list!
            // When IDLE: Transparent touch backdrop allowing Home/Explore to show through!
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                child: isTyping
                    ? Container(
                        key: const ValueKey('suggestions_view'),
                        width: double.infinity,
                        height: double.infinity,
                        color: surfaceColor,
                        child: _buildSuggestionsContent(isDark),
                      )
                    : GestureDetector(
                        key: const ValueKey('dismiss_backdrop'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Header with iOS Back Chevron and Centered Title ───────────────
  Widget _buildTopHeader(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              CupertinoIcons.chevron_back, // iOS back button style
              color: textColor,
              size: 26,
            ),
            splashRadius: 22,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              'Search for properties, hostels & rentals',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 40), // Balances the 40px back button so title is centered
        ],
      ),
    );
  }

  // ── Recently Searched Properties in Top Card (Increased size a little bit) ───
  Widget _buildRecentSearchesSection(bool isDark) {
    if (_recentSearches.isEmpty) return const SizedBox(height: 12);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  thickness: 1,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Recently searched properties',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  thickness: 1,
                  height: 1,
                ),
              ),
            ],
          ),
        ),

        // Horizontal list of history pill chips (increased size for comfortable touch targets)
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentSearches.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return BouncingButton(
                onTap: () => _applySearchQuery(query),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 17,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        query,
                        style: GoogleFonts.dmSans(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
  // ── Suggestions Content (Matching Screenshot 2) ───────────────────────
  Widget _buildSuggestionsContent(bool isDark) {
    final filtered = _getFilteredProperties();

    if (filtered.isEmpty && _locationSuggestions.isEmpty && !_isSearchingLocations) {
      final fallbackProps = _allProperties.take(6).toList();

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(
            child: Icon(
              CupertinoIcons.search,
              size: 44,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "No properties found for '$_searchQuery'",
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try searching by location (e.g. Diwancheruvu), property type (Hostel, 2 BHK), or landmark.",
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // Suggestion Chips (small letters, body text size)
          Text(
            "Popular searches",
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _defaultRecentSearches.map((chip) {
              return BouncingButton(
                onTap: () => _applySearchQuery(chip),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    chip,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (fallbackProps.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              "Available properties nearby",
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            ...fallbackProps.map((prop) => _buildPropertySuggestionItem(prop, isDark)),
          ],
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // ── Location Suggestions from Photon ──
        if (_locationSuggestions.isNotEmpty || _isSearchingLocations) ...[
          if (_isSearchingLocations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            )
          else
            ..._locationSuggestions.map((loc) => _buildLocationSuggestionItem(loc, isDark)),
          const SizedBox(height: 8),
        ],

        // ── Property Suggestions with Organized Cards & iOS Action Icon ──
        ...filtered.map((prop) => _buildPropertySuggestionItem(prop, isDark)),
      ],
    );
  }

  // ── Property Suggestion Item (Clean 2-line layout: Name + Location only) ───────
  Widget _buildPropertySuggestionItem(PropertyModel prop, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final firstImg = prop.imageUrls.isNotEmpty ? prop.imageUrls.first : '';

    String cleanLocation = prop.locationStr.trim();
    if (cleanLocation.isEmpty) {
      cleanLocation = prop.area.trim();
    }
    if (cleanLocation.isEmpty) {
      cleanLocation = 'Diwancheruvu, Rajahmundry';
    }

    final isPromoted = _activePromotions.containsKey(prop.id);
    final subtitleText = isPromoted ? 'FEATURED • $cleanLocation' : cleanLocation;

    return BouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        _saveRecentSearch(prop.title);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: prop)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Square Image Thumbnail (46x46 matching square location icon)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                child: firstImg.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: firstImg,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          CupertinoIcons.building_2_fill,
                          size: 22,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.building_2_fill,
                        size: 22,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Only essential info: Name + Location (Clean 2-line layout)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHighlightedTitle(prop.title, _searchQuery, textColor),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location Suggestion Item from Photon API ──────────────────────────
  Widget _buildLocationSuggestionItem(dynamic feature, bool isDark) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final name = props['name']?.toString() ?? 'Area';
    final city = props['city']?.toString() ?? props['district']?.toString() ?? 'Rajahmundry';
    final state = props['state']?.toString() ?? 'Andhra Pradesh';
    final coords = feature['geometry']?['coordinates'] as List?;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return BouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        _saveRecentSearch(name);

        Position? pos;
        if (coords != null && coords.length >= 2) {
          pos = Position(
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 1,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }

        Navigator.pop(context, {
          'position': pos,
          'city': name,
          'area': '$city, $state',
          'query': name,
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.location_solid,
                  size: 22,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHighlightedTitle(name, _searchQuery, textColor),
                  const SizedBox(height: 2),
                  Text(
                    '$city, $state',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Highlight Matching Query in Bold (Exact look from Screenshot 2) ───
  Widget _buildHighlightedTitle(String fullText, String query, Color textColor) {
    if (query.trim().isEmpty) {
      return Text(
        fullText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      );
    }

    final lowerText = fullText.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        fullText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      );
    }

    final before = fullText.substring(0, index);
    final match = fullText.substring(index, index + lowerQuery.length);
    final after = fullText.substring(index + lowerQuery.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: GoogleFonts.dmSans(
          fontSize: 15.0,
          color: textColor,
        ),
        children: [
          if (before.isNotEmpty)
            TextSpan(
              text: before,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.w800, // Matching query part is bold!
            ),
          ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
        ],
      ),
    );
  }
}
