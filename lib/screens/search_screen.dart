import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';
import 'home_screen.dart' show PropertyModel;
import 'property_details_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<PropertyModel> properties;
  final Position? currentPosition;
  final String initialCategory;
  final String initialQuery;

  const SearchScreen({
    super.key,
    required this.properties,
    this.currentPosition,
    this.initialCategory = 'All',
    this.initialQuery = '',
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  late String _selectedCategory; // 'All', 'PG', 'Rental', 'Buy'
  String _sortBy = 'relevance'; // 'relevance', 'distance', 'price_asc', 'price_desc'
  final FocusNode _focusNode = FocusNode();

  // Bottom Sheet Filter States
  String? _filterBhk; // '1 BHK', '2 BHK', '3 BHK', '4+ BHK'
  double? _filterMaxPrice; // 5000, 10000, 20000, 50000
  double? _filterMaxDistanceKm; // 2, 5, 10
  bool _filterHasAc = false;
  bool _filterHasFood = false;
  bool _filterFurnished = false;

  final List<String> _popularKeywords = [
    '2 BHK Flat',
    'Boys Hostel with Food',
    'Girls PG AC Room',
    'Independent House for Sale',
    '1 BHK Under ₹8,000',
    'Luxury Villa',
    'Commercial Office',
    'Gated Community',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _searchController = TextEditingController(text: widget.initialQuery);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _filterBhk != null ||
      _filterMaxPrice != null ||
      _filterMaxDistanceKm != null ||
      _filterHasAc ||
      _filterHasFood ||
      _filterFurnished;

  int get _activeFilterCount {
    int count = 0;
    if (_filterBhk != null) count++;
    if (_filterMaxPrice != null) count++;
    if (_filterMaxDistanceKm != null) count++;
    if (_filterHasAc) count++;
    if (_filterHasFood) count++;
    if (_filterFurnished) count++;
    return count;
  }

  double _parsePrice(String priceStr) {
    try {
      final clean = priceStr.replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse(clean) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  List<PropertyModel> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();

    List<PropertyModel> list = widget.properties.where((p) {
      // 1. Category filter
      if (_selectedCategory == 'PG' && p.type != 'PG' && p.type != 'Hostel') {
        return false;
      }
      if (_selectedCategory == 'Rental' && p.type != 'Rental' && p.type != 'House') {
        return false;
      }
      if (_selectedCategory == 'Buy' && p.type != 'Buy' && p.type != 'Sale' && p.type != 'Plot' && p.type != 'Land') {
        return false;
      }

      // 2. Distance Filter
      if (_filterMaxDistanceKm != null && widget.currentPosition != null) {
        double distInMeters = Geolocator.distanceBetween(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
          p.latitude,
          p.longitude,
        );
        if (distInMeters > (_filterMaxDistanceKm! * 1000)) return false;
      }

      // 3. Price Filter
      if (_filterMaxPrice != null) {
        if (_parsePrice(p.price) > _filterMaxPrice!) return false;
      }

      // 4. BHK Filter
      if (_filterBhk != null) {
        final b = _filterBhk!.toLowerCase();
        if (b == '1 bhk' && !p.beds.toLowerCase().contains('1 bhk') && !(p.bhkType?.toLowerCase().contains('1') ?? false)) {
          return false;
        } else if (b == '2 bhk' && !p.beds.toLowerCase().contains('2 bhk') && !(p.bhkType?.toLowerCase().contains('2') ?? false)) {
          return false;
        } else if (b == '3 bhk' && !p.beds.toLowerCase().contains('3 bhk') && !(p.bhkType?.toLowerCase().contains('3') ?? false)) {
          return false;
        } else if (b == '4+ bhk') {
          final bedsStr = p.beds.toLowerCase();
          if (!bedsStr.contains('4') && !bedsStr.contains('5') && !(p.bhkType?.toLowerCase().contains('4') ?? false)) {
            return false;
          }
        }
      }

      // 5. AC Filter
      if (_filterHasAc) {
        final acInfo = (p.acType ?? '').toLowerCase();
        final hasAc = acInfo.contains('ac') || p.features.any((f) => f.toLowerCase().contains('ac'));
        if (!hasAc) return false;
      }

      // 6. Food Filter
      if (_filterHasFood) {
        final foodInfo = (p.foodDetails ?? '').toLowerCase();
        final hasFood = foodInfo.contains('food') || foodInfo.contains('meal') || p.perDayWithFood != null;
        if (!hasFood) return false;
      }

      // 7. Furnished Filter
      if (_filterFurnished) {
        final furn = (p.furnishingStatus ?? '').toLowerCase();
        if (!furn.contains('furnish') || furn.contains('unfurnished')) return false;
      }

      // 8. Text query filter
      if (query.isEmpty) return true;

      final titleMatch = p.title.toLowerCase().contains(query);
      final locationMatch = p.locationStr.toLowerCase().contains(query);
      final priceMatch = p.price.toLowerCase().contains(query);
      final bedsMatch = p.beds.toLowerCase().contains(query);
      final typeMatch = p.type.toLowerCase().contains(query);
      final bhkMatch = (p.bhkType ?? '').toLowerCase().contains(query);
      final featuresMatch = p.features.any((f) => f.toLowerCase().contains(query));
      final tagsMatch = p.tags.any((t) => t.toLowerCase().contains(query));

      return titleMatch || locationMatch || priceMatch || bedsMatch || typeMatch || bhkMatch || featuresMatch || tagsMatch;
    }).toList();

    // Sorting
    if (_sortBy == 'distance' && widget.currentPosition != null) {
      list.sort((a, b) {
        double distA = Geolocator.distanceBetween(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        double distB = Geolocator.distanceBetween(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
    } else if (_sortBy == 'price_asc') {
      list.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
    } else if (_sortBy == 'price_desc') {
      list.sort((a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)));
    }

    return list;
  }

  String _formatDistance(PropertyModel property) {
    if (widget.currentPosition == null) return '';
    double distanceInMeters = Geolocator.distanceBetween(
      widget.currentPosition!.latitude,
      widget.currentPosition!.longitude,
      property.latitude,
      property.longitude,
    );
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m away';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = _filteredProperties;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFFBF7F7),
      floatingActionButton: _buildFloatingFilterButton(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar & Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _buildSearchBar(isDark),
            ),

            // Category Tabs ('All', 'Hostel / PG', 'Rental', 'Buy / Sale')
            _buildCategoryTabs(isDark),

            const SizedBox(height: 4),

            // Sort & Results Count Bar (No black divider line)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${results.length} ${results.length == 1 ? 'property' : 'properties'} found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                    ),
                  ),
                  _buildSortButton(isDark),
                ],
              ),
            ),

            // Main Content: Popular Suggestions OR Results List
            Expanded(
              child: results.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 95),
                      itemCount: results.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _buildPropertyCard(results[index], isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingFilterButton(bool isDark) {
    final hasFilters = _hasActiveFilters;

    return BouncingButton(
      scaleFactor: 0.93,
      onTap: () {
        HapticFeedback.selectionClick();
        _openFiltersBottomSheet();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.primaryYellow : Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? AppTheme.primaryYellow.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Iconsax.setting_4,
              size: 26,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
          if (hasFilters)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_activeFilterCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Row(
      children: [
        // Back Button
        BouncingButton(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Iconsax.arrow_left_2,
              color: isDark ? Colors.white : Colors.black87,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Search Input Box
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.search_normal_1,
                  size: 20,
                  color: isDark ? AppTheme.primaryYellow : Colors.black87,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search city, area, 2 BHK, hostel, buy...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Iconsax.close_circle5,
                        size: 19,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    final categories = [
      {'label': 'All', 'key': 'All', 'icon': Iconsax.category},
      {'label': 'Hostel / PG', 'key': 'PG', 'icon': Iconsax.building_3},
      {'label': 'Rental', 'key': 'Rental', 'icon': Iconsax.home_2},
      {'label': 'Buy / Sale', 'key': 'Buy', 'icon': Iconsax.shop},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: BouncingButton(
              scaleFactor: 0.96,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat['key'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppTheme.primaryYellow : Colors.black)
                      : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppTheme.primaryYellow : Colors.black)
                        : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: isDark
                            ? AppTheme.primaryYellow.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 15,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? AppTheme.darkTextSecondary : Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortButton(bool isDark) {
    String label = 'Closest';
    if (_sortBy == 'price_asc') label = 'Price: Low';
    if (_sortBy == 'price_desc') label = 'Price: High';
    if (_sortBy == 'relevance') label = 'Relevance';

    return GestureDetector(
      onTap: _showSortBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.sort,
              size: 14,
              color: isDark ? AppTheme.primaryYellow : Colors.black87,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Sort Results By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Relevance (Default)', 'relevance', Iconsax.magic_star, isDark),
                if (widget.currentPosition != null)
                  _buildSortOption('Distance (Closest First)', 'distance', Iconsax.location, isDark),
                _buildSortOption('Price: Low to High', 'price_asc', Iconsax.arrow_up_3, isDark),
                _buildSortOption('Price: High to Low', 'price_desc', Iconsax.arrow_down_1, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, String key, IconData icon, bool isDark) {
    final isSelected = _sortBy == key;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? (isDark ? AppTheme.primaryYellow : Colors.black) : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? (isDark ? AppTheme.primaryYellow : Colors.black) : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: isDark ? AppTheme.primaryYellow : Colors.black)
          : null,
      onTap: () {
        setState(() => _sortBy = key);
        Navigator.pop(context);
      },
    );
  }

  void _openFiltersBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? tempBhk = _filterBhk;
    double? tempPrice = _filterMaxPrice;
    double? tempDist = _filterMaxDistanceKm;
    bool tempAc = _filterHasAc;
    bool tempFood = _filterHasFood;
    bool tempFurnished = _filterFurnished;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Properties',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempBhk = null;
                            tempPrice = null;
                            tempDist = null;
                            tempAc = false;
                            tempFood = false;
                            tempFurnished = false;
                          });
                        },
                        child: Text(
                          'Reset All',
                          style: TextStyle(
                            color: isDark ? AppTheme.primaryYellow : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),

                  // Filter Content
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        const SizedBox(height: 14),

                        // BHK Filter
                        _buildFilterSectionTitle('BHK / Layout Configuration'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['1 BHK', '2 BHK', '3 BHK', '4+ BHK'].map((bhk) {
                            final isSel = tempBhk == bhk;
                            return _buildSelectableChip(
                              label: bhk,
                              isSelected: isSel,
                              isDark: isDark,
                              onTap: () {
                                setSheetState(() => tempBhk = isSel ? null : bhk);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Budget Filter
                        _buildFilterSectionTitle('Maximum Budget'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            {'label': 'Under ₹5,000', 'val': 5000.0},
                            {'label': 'Under ₹10,000', 'val': 10000.0},
                            {'label': 'Under ₹20,000', 'val': 20000.0},
                            {'label': 'Under ₹50,000', 'val': 50000.0},
                          ].map((item) {
                            final isSel = tempPrice == item['val'];
                            return _buildSelectableChip(
                              label: item['label'] as String,
                              isSelected: isSel,
                              isDark: isDark,
                              onTap: () {
                                setSheetState(() => tempPrice = isSel ? null : item['val'] as double);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Distance Filter
                        if (widget.currentPosition != null) ...[
                          _buildFilterSectionTitle('Distance / Radius'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              {'label': 'Within 2 km', 'val': 2.0},
                              {'label': 'Within 5 km', 'val': 5.0},
                              {'label': 'Within 10 km', 'val': 10.0},
                            ].map((item) {
                              final isSel = tempDist == item['val'];
                              return _buildSelectableChip(
                                label: item['label'] as String,
                                isSelected: isSel,
                                isDark: isDark,
                                onTap: () {
                                  setSheetState(() => tempDist = isSel ? null : item['val'] as double);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Amenities & Preferences
                        _buildFilterSectionTitle('Features & Preferences'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSelectableChip(
                              label: 'AC Rooms',
                              isSelected: tempAc,
                              isDark: isDark,
                              onTap: () {
                                setSheetState(() => tempAc = !tempAc);
                              },
                            ),
                            _buildSelectableChip(
                              label: 'Food Included',
                              isSelected: tempFood,
                              isDark: isDark,
                              onTap: () {
                                setSheetState(() => tempFood = !tempFood);
                              },
                            ),
                            _buildSelectableChip(
                              label: 'Furnished',
                              isSelected: tempFurnished,
                              isDark: isDark,
                              onTap: () {
                                setSheetState(() => tempFurnished = !tempFurnished);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Apply Button
                  const SizedBox(height: 12),
                  BouncingButton(
                    onTap: () {
                      setState(() {
                        _filterBhk = tempBhk;
                        _filterMaxPrice = tempPrice;
                        _filterMaxDistanceKm = tempDist;
                        _filterHasAc = tempAc;
                        _filterHasFood = tempFood;
                        _filterFurnished = tempFurnished;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.primaryYellow : Colors.black,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.primaryYellow : Colors.black)
              : (isDark ? AppTheme.darkCardElevated : const Color(0xFFF0F0F4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.primaryYellow : Colors.black)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel prop, bool isDark) {
    final distance = _formatDistance(prop);
    final isBuy = prop.type == 'Buy' || prop.type == 'Sale';
    final isPg = prop.type == 'PG' || prop.type == 'Hostel';

    return BouncingButton(
      scaleFactor: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailsScreen(property: prop),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Showcase with Badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 175,
                    width: double.infinity,
                    child: prop.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: prop.imageUrls.first,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: isDark ? AppTheme.darkCardElevated : Colors.grey.shade200,
                              child: Icon(Iconsax.home_2, size: 40, color: Colors.grey.shade400),
                            ),
                          )
                        : Container(
                            color: isDark ? AppTheme.darkCardElevated : Colors.grey.shade200,
                            child: Icon(Iconsax.home_2, size: 40, color: Colors.grey.shade400),
                          ),
                  ),
                ),

                // Category Badge (Top Left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBuy ? Iconsax.shop : (isPg ? Iconsax.building_3 : Iconsax.home_2),
                          size: 13,
                          color: isBuy ? const Color(0xFFFFEB3A) : (isPg ? Colors.blue : Colors.green),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isBuy ? 'For Sale' : (isPg ? 'PG / Hostel' : 'Rental'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Distance Badge (Top Right)
                if (distance.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.location, size: 12, color: Color(0xFFFFEB3A)),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Price Pill (Bottom Right of Image)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      prop.price,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body Info
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Verified Icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          prop.title,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 17,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Iconsax.location,
                        size: 14,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          prop.locationStr,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Specifications & Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (prop.beds.isNotEmpty)
                        _buildInfoChip(Iconsax.home, prop.beds, isDark),
                      if (prop.area.isNotEmpty)
                        _buildInfoChip(Iconsax.ruler, prop.area, isDark),
                      if (prop.furnishingStatus != null && prop.furnishingStatus!.isNotEmpty)
                        _buildInfoChip(Iconsax.lamp, prop.furnishingStatus!, isDark),
                      if (prop.genderPreference != null && prop.genderPreference!.isNotEmpty)
                        _buildInfoChip(Iconsax.user, prop.genderPreference!, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF3F3F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(
                  Iconsax.search_status,
                  size: 64,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                const SizedBox(height: 14),
                Text(
                  'No matching properties found',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try searching for another area, category, or budget',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Popular Suggestions
          Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularKeywords.map((kw) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _searchController.text = kw;
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.search_normal,
                        size: 13,
                        color: isDark ? AppTheme.primaryYellow : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kw,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
