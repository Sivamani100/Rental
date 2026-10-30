import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/partner/data/models/partner_promotion_model.dart';
import 'package:rental/features/home/presentation/widgets/filter_bottom_sheet.dart';

// Top-level isolate helper for JSON parsing
List<PropertyModel> _parsePropertiesIsolate(String jsonStr) {
  final decoded = jsonDecode(jsonStr) as List;
  return decoded
      .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

class PopularSearchItem {
  final String label;
  final String query;
  final String category; // 'All', 'PG', 'Rental', 'Buy'
  final IconData icon;
  final bool isLocation;
  final double? latitude;
  final double? longitude;
  final String? area;

  const PopularSearchItem({
    required this.label,
    required this.query,
    required this.category,
    required this.icon,
    this.isLocation = false,
    this.latitude,
    this.longitude,
    this.area,
  });
}

class UnifiedSearchScreen extends StatefulWidget {
  final List<PropertyModel>? initialProperties;
  final String? initialQuery;
  final String? initialCategory;
  final Position? currentPosition;

  const UnifiedSearchScreen({
    super.key,
    this.initialProperties,
    this.initialQuery,
    this.initialCategory,
    this.currentPosition,
  });

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

  final _supabase = Supabase.instance.client;
  Map<String, PartnerPromotionModel> _activePromotions = {};

  String _selectedCategory = 'All'; // 'All', 'PG', 'Rental', 'Buy'
  final FilterState _filterState = const FilterState();
  PopularSearchItem? _activePopularFilter;

  List<String> _recentSearches = [];
  static const List<String> _defaultRecentSearches = [
    'Diwancheruvu',
    'Hostels & PG',
    'Rajahmundry',
    'Furnished Rentals',
    'Lalacheruvu',
    'Visakhapatnam',
  ];

  static const List<PopularSearchItem> _popularSearches = [
    // Requested Locations with exact coordinates & region
    PopularSearchItem(
      label: 'Diwancheruvu',
      query: 'Diwancheruvu',
      category: 'All',
      icon: CupertinoIcons.location_solid,
      isLocation: true,
      latitude: 17.0673,
      longitude: 81.8267,
      area: 'Rajahmundry Rural, Andhra Pradesh',
    ),
    PopularSearchItem(
      label: 'Rajahmundry',
      query: 'Rajahmundry',
      category: 'All',
      icon: CupertinoIcons.location_solid,
      isLocation: true,
      latitude: 17.0005,
      longitude: 81.8040,
      area: 'East Godavari, Andhra Pradesh',
    ),
    PopularSearchItem(
      label: 'Lalacheruvu',
      query: 'Lalacheruvu',
      category: 'All',
      icon: CupertinoIcons.location_solid,
      isLocation: true,
      latitude: 17.0270,
      longitude: 81.8150,
      area: 'Rajahmundry, Andhra Pradesh',
    ),
    PopularSearchItem(
      label: 'Visakhapatnam',
      query: 'Visakhapatnam',
      category: 'All',
      icon: CupertinoIcons.location_solid,
      isLocation: true,
      latitude: 17.6868,
      longitude: 83.2185,
      area: 'Visakhapatnam, Andhra Pradesh',
    ),
    // Popular Property Types & Features
    PopularSearchItem(
      label: 'Hostels & PG',
      query: 'Hostel',
      category: 'PG',
      icon: CupertinoIcons.building_2_fill,
    ),
    PopularSearchItem(
      label: 'Furnished Rentals',
      query: 'Furnished',
      category: 'Rental',
      icon: CupertinoIcons.house_fill,
    ),
    PopularSearchItem(
      label: '1 BHK Flats',
      query: '1 BHK',
      category: 'Rental',
      icon: CupertinoIcons.bed_double_fill,
    ),
    PopularSearchItem(
      label: '2 BHK Flats',
      query: '2 BHK',
      category: 'Rental',
      icon: CupertinoIcons.square_stack_3d_up_fill,
    ),
    PopularSearchItem(
      label: 'Single Room PG',
      query: 'Single Room',
      category: 'PG',
      icon: CupertinoIcons.person_fill,
    ),
    PopularSearchItem(
      label: 'Girls Hostel',
      query: 'Girls Hostel',
      category: 'PG',
      icon: CupertinoIcons.person_crop_circle_fill,
    ),
    PopularSearchItem(
      label: 'Boys Hostel',
      query: 'Boys Hostel',
      category: 'PG',
      icon: CupertinoIcons.person_crop_circle,
    ),
    PopularSearchItem(
      label: 'Buy Properties',
      query: 'Buy',
      category: 'Buy',
      icon: CupertinoIcons.bag_fill,
    ),
    PopularSearchItem(
      label: 'Zero Deposit',
      query: 'Zero Deposit',
      category: 'All',
      icon: CupertinoIcons.money_dollar_circle_fill,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Fast initial load without blocking UI thread
    if (widget.initialProperties != null && widget.initialProperties!.isNotEmpty) {
      _allProperties = List.from(widget.initialProperties!);
    } else {
      _loadCachedProperties();
    }

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
      // Trigger search for initial query (e.g., from voice search)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearchChanged(widget.initialQuery!);
      });
    }
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }

    _fetchActivePromotions();
    _loadRecentSearches();

    // Smooth delay before keyboard focus to guarantee 60/120fps route transition
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasStored = prefs.containsKey('recent_searches');
      if (hasStored) {
        final list = prefs.getStringList('recent_searches') ?? [];
        if (mounted) {
          setState(() {
            _recentSearches = list;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _recentSearches = List.from(_defaultRecentSearches);
          });
        }
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
      if (mounted) {
        setState(() {
          _recentSearches = list;
        });
      }
    } catch (_) {}
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
          });
        }
      }
    } catch (_) {}
  }

  bool _isPropertyTypeKeyword(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'hostel' ||
        lower == 'hostels' ||
        lower == 'pg' ||
        lower == 'furnished' ||
        lower == 'furnished rentals' ||
        lower == 'furnished rental' ||
        lower.contains('bhk') ||
        lower.contains('single room') ||
        lower.contains('girls') ||
        lower.contains('boys') ||
        lower.contains('ladies') ||
        lower.contains('gents') ||
        lower == 'buy' ||
        lower.contains('deposit');
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    // Do NOT trigger photon location lookup for property type keywords
    if (_isPropertyTypeKeyword(val)) {
      if (mounted) {
        setState(() {
          _locationSuggestions = [];
          _isSearchingLocations = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
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
    setState(() {
      _isSearchingLocations = true;
    });
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RentalApp/1.0.0 (contact@rental.arkio.in)',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && mounted) {
          setState(() {
            _locationSuggestions = List.from(data['features']);
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isSearchingLocations = false;
      });
    }
  }

  bool _matchesQuery(PropertyModel p, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();

    // 1. Hostels / PG matching
    if (q == 'hostel' || q == 'hostels' || q == 'pg' || q == 'hostel & pg' || q == 'hostels & pg') {
      final t = p.type.toLowerCase();
      final title = p.title.toLowerCase();
      if (t.contains('pg') || t.contains('hostel') || t.contains('paying guest') || t.contains('coliving')) return true;
      if (title.contains('pg') || title.contains('hostel') || title.contains('guest house') || title.contains('dormitory')) return true;
      if (p.tags.any((tag) => tag.toLowerCase().contains('pg') || tag.toLowerCase().contains('hostel') || tag.toLowerCase().contains('sharing') || tag.toLowerCase().contains('boys') || tag.toLowerCase().contains('girls'))) return true;
      if (p.sharingType != null && p.sharingType!.isNotEmpty) return true;
      return false;
    }

    // 2. Furnished matching (e.g. Furnished Rentals)
    if (q == 'furnished' || q == 'furnished rentals' || q == 'furnished rental') {
      final f = (p.furnishingStatus ?? '').toLowerCase();
      final isFurnishedStatus = f.contains('furnish') && !f.contains('unfurnish');
      final isFurnishedFeature = p.features.any((feat) {
        final featLower = feat.toLowerCase();
        return featLower.contains('furnish') && !featLower.contains('unfurnish');
      });
      final isFurnishedTag = p.tags.any((tag) {
        final tagLower = tag.toLowerCase();
        return tagLower.contains('furnish') && !tagLower.contains('unfurnish');
      });
      final isFurnishedTitle = p.title.toLowerCase().contains('furnish') &&
          !p.title.toLowerCase().contains('unfurnish');

      return isFurnishedStatus || isFurnishedFeature || isFurnishedTag || isFurnishedTitle;
    }

    // 3. Single Room / Single Sharing
    if (q == 'single' || q == 'single room' || q == 'single room pg') {
      final sh = (p.sharingType ?? '').toLowerCase();
      final beds = p.beds.toLowerCase();
      final bhk = (p.bhkType ?? '').toLowerCase();
      final title = p.title.toLowerCase();
      return sh.contains('single') ||
          sh.contains('1 sharing') ||
          beds.contains('single') ||
          bhk.contains('1') ||
          title.contains('single');
    }

    // 4. 2 BHK Flats
    if (q == '2 bhk' || q == '2bhk' || q == '2 bhk flats' || q == '2 bhk flat') {
      final bhk = (p.bhkType ?? '').toLowerCase();
      final beds = p.beds.toLowerCase();
      final title = p.title.toLowerCase();
      return bhk.contains('2') || beds.contains('2') || title.contains('2 bhk') || title.contains('2bhk');
    }

    // 5. 1 BHK Flats
    if (q == '1 bhk' || q == '1bhk' || q == '1 bhk flats' || q == '1 bhk flat') {
      final bhk = (p.bhkType ?? '').toLowerCase();
      final beds = p.beds.toLowerCase();
      final title = p.title.toLowerCase();
      return bhk.contains('1') || beds.contains('1') || title.contains('1 bhk') || title.contains('1bhk');
    }

    // 6. Girls Hostel / PG
    if (q == 'girls' || q == 'girls hostel' || q == 'girls pg' || q == 'ladies hostel' || q == 'women hostel') {
      final g = (p.genderPreference ?? '').toLowerCase();
      final title = p.title.toLowerCase();
      return g.contains('girl') ||
          g.contains('female') ||
          g.contains('women') ||
          g.contains('ladies') ||
          title.contains('girl') ||
          title.contains('female') ||
          title.contains('women') ||
          title.contains('ladies');
    }

    // 7. Boys Hostel / PG
    if (q == 'boys' || q == 'boys hostel' || q == 'boys pg' || q == 'gents hostel' || q == 'men hostel') {
      final g = (p.genderPreference ?? '').toLowerCase();
      final title = p.title.toLowerCase();
      return g.contains('boy') ||
          g.contains('male') ||
          g.contains('men') ||
          g.contains('gent') ||
          title.contains('boy') ||
          title.contains('male') ||
          title.contains('men') ||
          title.contains('gent');
    }

    // 8. Buy Properties
    if (q == 'buy' || q == 'buy properties' || q == 'sale') {
      final t = p.type.toLowerCase();
      final title = p.title.toLowerCase();
      return t.contains('buy') ||
          t.contains('sale') ||
          t.contains('plot') ||
          t.contains('land') ||
          title.contains('buy') ||
          title.contains('sale') ||
          title.contains('plot');
    }

    // 9. Zero Deposit
    if (q == 'zero deposit' || q == 'no deposit') {
      final dep = (p.securityDeposit ?? '').toLowerCase();
      return dep.isEmpty ||
          dep == '0' ||
          dep.contains('zero') ||
          dep.contains('no') ||
          p.tags.any((t) => t.toLowerCase().contains('zero') || t.toLowerCase().contains('deposit'));
    }

    // 10. Location Semantic & Alias Matching (Diwancheruvu, Rajahmundry, Lalacheruvu, Visakhapatnam)
    if (q.contains('diwancheruvu') ||
        q.contains('diwanchervuvu') ||
        q.contains('divancheruvu') ||
        q.contains('diwanchervu')) {
      final loc = '${p.locationStr} ${p.title} ${p.description ?? ''}'.toLowerCase();
      if (loc.contains('diwancheruvu') ||
          loc.contains('diwanchervuvu') ||
          loc.contains('divancheruvu') ||
          loc.contains('diwanchervu')) {
        return true;
      }
    }

    if (q.contains('rajahmundry') ||
        q.contains('rajamundry') ||
        q.contains('rajamahendravaram')) {
      final loc = '${p.locationStr} ${p.title} ${p.description ?? ''}'.toLowerCase();
      if (loc.contains('rajahmundry') ||
          loc.contains('rajamundry') ||
          loc.contains('rajamahendravaram')) {
        return true;
      }
    }

    if (q.contains('lalacheruvu') || q.contains('lala cheruvu')) {
      final loc = '${p.locationStr} ${p.title} ${p.description ?? ''}'.toLowerCase();
      if (loc.contains('lalacheruvu') || loc.contains('lala cheruvu')) {
        return true;
      }
    }

    if (q.contains('visakhapatnam') || q.contains('vizag')) {
      final loc = '${p.locationStr} ${p.title} ${p.description ?? ''}'.toLowerCase();
      if (loc.contains('visakhapatnam') || loc.contains('vizag')) {
        return true;
      }
    }

    // 11. Multi-token comprehensive search:
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;

    final fullSearchableText = [
      p.title,
      p.locationStr,
      p.type,
      p.bhkType ?? '',
      p.furnishingStatus ?? '',
      p.genderPreference ?? '',
      p.sharingType ?? '',
      p.beds,
      p.baths,
      p.area,
      p.tags.join(' '),
      p.features.join(' '),
      p.description ?? '',
    ].join(' ').toLowerCase();

    return words.every((word) => fullSearchableText.contains(word));
  }

  List<PropertyModel> _getFilteredProperties() {
    List<PropertyModel> list = _allProperties;

    // 1. Filter by Selected Category Pill
    if (_selectedCategory == 'PG') {
      list = list.where((p) {
        final t = p.type.toLowerCase();
        final title = p.title.toLowerCase();
        return t.contains('pg') ||
            t.contains('hostel') ||
            t.contains('paying guest') ||
            t.contains('coliving') ||
            title.contains('pg') ||
            title.contains('hostel') ||
            title.contains('guest house') ||
            title.contains('dormitory') ||
            p.tags.any((tag) => tag.toLowerCase().contains('pg') || tag.toLowerCase().contains('hostel') || tag.toLowerCase().contains('sharing')) ||
            (p.sharingType != null && p.sharingType!.isNotEmpty);
      }).toList();
    } else if (_selectedCategory == 'Rental') {
      list = list.where((p) {
        final t = p.type.toLowerCase();
        return t.contains('rental') || t.contains('house') || t.contains('flat') || t.contains('apartment');
      }).toList();
    } else if (_selectedCategory == 'Buy') {
      list = list.where((p) {
        final t = p.type.toLowerCase();
        return t.contains('buy') || t.contains('sale') || t.contains('plot') || t.contains('land');
      }).toList();
    }

    // 2. Filter by Active Popular Search item (if tapped, e.g. Furnished Rentals, 1 BHK, Girls Hostel)
    if (_activePopularFilter != null) {
      final q = _activePopularFilter!.query.toLowerCase();
      list = list.where((p) => _matchesQuery(p, q)).toList();
    }

    // 3. Filter by User Typed Search Query
    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((p) => _matchesQuery(p, _searchQuery)).toList();
    }

    // 4. Apply Sort from FilterState
    if (_filterState.sortBy == 'price_asc') {
      list.sort((a, b) {
        final pa = _parseNumericPrice(a.price);
        final pb = _parseNumericPrice(b.price);
        return pa.compareTo(pb);
      });
    } else if (_filterState.sortBy == 'price_desc') {
      list.sort((a, b) {
        final pa = _parseNumericPrice(a.price);
        final pb = _parseNumericPrice(b.price);
        return pb.compareTo(pa);
      });
    } else {
      // Default: promoted first, followed by proximity (location-wise)
      final pos = widget.currentPosition;
      list.sort((a, b) {
        final promoA = a.id != null ? _activePromotions[a.id] : null;
        final promoB = b.id != null ? _activePromotions[b.id] : null;
        if (promoA != null && promoB == null) return -1;
        if (promoA == null && promoB != null) return 1;
        if (promoA != null && promoB != null) {
          final comp = promoA.priorityPosition.compareTo(promoB.priorityPosition);
          if (comp != 0) return comp;
        }
        if (pos != null) {
          final distA = Geolocator.distanceBetween(pos.latitude, pos.longitude, a.latitude, a.longitude);
          final distB = Geolocator.distanceBetween(pos.latitude, pos.longitude, b.latitude, b.longitude);
          return distA.compareTo(distB);
        }
        return 0;
      });
    }

    return list;
  }

  void _applyPopularSearch(PopularSearchItem item) {
    HapticFeedback.selectionClick();
    if (item.isLocation) {
      _saveRecentSearch(item.query);
      _searchFocusNode.unfocus();

      Position? pos;
      if (item.latitude != null && item.longitude != null) {
        pos = Position(
          latitude: item.latitude!,
          longitude: item.longitude!,
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
        'city': item.label,
        'area': item.area ?? 'Andhra Pradesh, India',
        'query': item.query,
      });
    } else {
      // Non-location items (Hostels, Furnished, 1 BHK, etc.) do NOT fill the search bar:
      // They directly filter and display matching listings!
      setState(() {
        if (_activePopularFilter?.label == item.label) {
          _activePopularFilter = null;
          _selectedCategory = 'All';
        } else {
          _activePopularFilter = item;
          _selectedCategory = item.category;
        }
        _searchController.clear();
        _searchQuery = '';
        _locationSuggestions = [];
        _isSearchingLocations = false;
      });
    }
  }


  double _parseNumericPrice(String rawPrice) {
    final clean = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  String _formatPrice(String rawPrice) {
    final clean = rawPrice.trim();
    if (clean.isEmpty) return '₹0';
    if (clean.startsWith('₹')) return clean;
    return '₹$clean';
  }

  Color _getTypeColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('pg') || lower.contains('hostel')) {
      return const Color(0xFF6366F1); // Indigo / Violet
    } else if (lower.contains('buy') || lower.contains('sale')) {
      return const Color(0xFF10B981); // Emerald Green
    } else {
      return const Color(0xFF3B82F6); // Ocean Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkScaffold : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Clean Top Search Header ───────────────────────────────────────
            _buildSearchHeader(isDark),

            const SizedBox(height: 4),

            // ── Body / Results Content ────────────────────────────────────────
            Expanded(
              child: _buildBody(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    // Sort page surface and border style
    final surfaceColor = isDark ? const Color(0xFF282828) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), // Minimum proper margin on both sides
      child: Container(
        height: 56, // Increased height for comfortable, premium touch target
        padding: const EdgeInsets.symmetric(horizontal: 4), // Proper inner padding on both sides
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          children: [
            // ── Back Button (INSIDE the search bar on left) ────────────────
            BouncingButton(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: primaryTextColor,
                  size: 20,
                ),
              ),
            ),

            // ── Clear gap after the back icon ─────────────────────────────
            const SizedBox(width: 8),

            // ── TextField (Search input) ───────────────────────────────────
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textSelectionTheme: TextSelectionThemeData(
                    cursorColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    selectionColor: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFF0F172A).withValues(alpha: 0.15),
                    selectionHandleColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  cursorColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _saveRecentSearch(val);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "Search areas, hostels, flats...",
                    hintStyle: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // ── Clear 'X' Button (When query is not empty) ─────────────────
            if (_searchQuery.isNotEmpty)
              BouncingButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _searchController.clear();
                  _onSearchChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 18,
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }



  Widget _buildBody(bool isDark) {
    final filtered = _getFilteredProperties();

    // When search is completely empty, show popular tags and trending listings
    if (_searchQuery.trim().isEmpty) {
      return _buildEmptyQueryContent(isDark, filtered);
    }

    final hasNoResults = filtered.isEmpty &&
        _locationSuggestions.isEmpty &&
        !_isSearchingLocations;

    if (hasNoResults) {
      return _buildNoResultsView(isDark);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [

        // ── Location Suggestions Section ──
        if (_locationSuggestions.isNotEmpty || _isSearchingLocations) ...[
          _buildSectionHeader(
            'AREAS & VILLAGES',
            CupertinoIcons.location_solid,
            isDark,
          ),
          const SizedBox(height: 8),
          if (_isSearchingLocations)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            )
          else
            ..._locationSuggestions.map((feature) => _buildLocationCard(feature, isDark)),
          const SizedBox(height: 18),
        ],

        // ── Properties Section ──
        if (filtered.isNotEmpty) ...[
          _buildSectionHeader(
            'PROPERTIES (${filtered.length})',
            CupertinoIcons.building_2_fill,
            isDark,
          ),
          const SizedBox(height: 10),
          ...filtered.take(30).map((p) => _buildPropertyCard(p, isDark)),
        ],
      ],
    );
  }

  Widget _buildEmptyQueryContent(bool isDark, List<PropertyModel> filteredProperties) {
    final title = _activePopularFilter != null
        ? _activePopularFilter!.label.toUpperCase()
        : 'TRENDING PROPERTIES';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Popular Searches Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9100).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.flame_fill,
                color: Color(0xFFFF9100),
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'POPULAR SEARCHES',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (_activePopularFilter != null)
              BouncingButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _activePopularFilter = null;
                    _selectedCategory = 'All';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282828) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Popular Searches List (Only Locations)
        ..._popularSearches.where((item) => item.isLocation).map((item) {
          final isSelected = _activePopularFilter?.label == item.label;
          return _buildPopularSearchTile(item, isSelected, isDark);
        }),

        const SizedBox(height: 28),

        // Properties Section (Shows matching listings directly!)
        if (filteredProperties.isNotEmpty) ...[
          _buildSectionHeader(
            '$title (${filteredProperties.length})',
            CupertinoIcons.sparkles,
            isDark,
          ),
          const SizedBox(height: 10),
          ...filteredProperties.take(25).map((p) => _buildPropertyCard(p, isDark)),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Text(
                'No listings found in this category',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }


  Widget _buildPopularSearchTile(PopularSearchItem item, bool isSelected, bool isDark) {
    return BouncingButton(
      onTap: () => _applyPopularSearch(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.5, horizontal: 4), // Generous space & gap between searches
        child: Row(
          children: [
            // Left: Clean magnifying glass icon as in screenshot
            Icon(
              CupertinoIcons.search,
              size: 20,
              color: isSelected
                  ? AppTheme.primaryYellow
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 16), // Clear space between icon and text

            // Middle: Search query text
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 15.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppTheme.primaryYellow : const Color(0xFFD97706))
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (isSelected) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.primaryYellow : const Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Right: Diagonal arrow (top-right ↗)
            BouncingButton(
              onTap: () {
                HapticFeedback.selectionClick();
                _searchController.text = item.query;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: item.query.length),
                );
                _onSearchChanged(item.query);
                _saveRecentSearch(item.query);
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 6, top: 4, bottom: 4),
                child: Icon(
                  CupertinoIcons.arrow_up_left,
                  size: 20,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(dynamic feature, bool isDark) {
    final props = feature['properties'] ?? {};
    final name = props['name'] ?? 'Unknown Location';
    final state = props['state'] ?? '';
    final county = props['county'] ?? '';

    final subtitleParts = [county, state]
        .where((e) => e.toString().trim().isNotEmpty)
        .toList();
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(', ')
        : 'Select area to view nearby properties';

    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: BouncingButton(
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
              accuracy: 1,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
            Navigator.pop(context, {
              'position': newPos,
              'city': name,
              'area': subtitle,
              'query': name,
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CupertinoIcons.location_solid,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.arrow_up_left,
                size: 16,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel p, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE);
    final typeColor = _getTypeColor(p.type);

    // Context badges (e.g. Furnishing or BHK)
    final furnishing = p.furnishingStatus?.trim();
    final bhkOrSharing = (p.bhkType != null && p.bhkType!.trim().isNotEmpty)
        ? p.bhkType!.trim()
        : (p.sharingType != null && p.sharingType!.trim().isNotEmpty
            ? p.sharingType!.trim()
            : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: BouncingButton(
        onTap: () {
          _searchFocusNode.unfocus();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(property: p),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Property Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: p.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: p.imageUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const CupertinoActivityIndicator(radius: 8),
                          ),
                          errorWidget: (ctx, url, err) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                            child: Icon(
                              CupertinoIcons.building_2_fill,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                              size: 26,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                          child: Icon(
                            CupertinoIcons.building_2_fill,
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            size: 26,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Property Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type pill & badges row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.type.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (furnishing != null && furnishing.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              furnishing,
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ] else if (bhkOrSharing != null) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              bhkOrSharing,
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                        if (p.viewsCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722).withValues(alpha: isDark ? 0.2 : 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.eye_fill,
                                  size: 9,
                                  color: Color(0xFFFF5722),
                                ),
                                const SizedBox(width: 2.5),
                                Text(
                                  '${p.viewsCount}',
                                  style: const TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF5722),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Title
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Location
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location,
                          size: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            p.locationStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      _formatPrice(p.price),
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.search,
                size: 28,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No matches found",
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We couldn't find anything matching '$_searchQuery'. Try checking for typos or searching a different area.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 13.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            BouncingButton(
              onTap: () {
                HapticFeedback.selectionClick();
                _searchController.clear();
                _onSearchChanged('');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryYellow.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Clear Search',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
