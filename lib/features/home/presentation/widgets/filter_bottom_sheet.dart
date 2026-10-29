import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:rental/app/theme/app_theme.dart';

class FilterState {
  final String selectedCategory; // 'Rental', 'PG', 'Buy'
  final double minBudget;
  final double maxBudget;
  final List<String> propertyTypes;
  final List<String> occupancy;
  final List<String> bathrooms;
  final List<String> amenities;
  final List<String> furnishing;
  final List<String> tenants;
  final List<String> bhkTypes;
  final List<String> genderPreference;
  final List<String> foodPreferences;
  final List<String> roomTypes;
  final List<String> parking;
  final List<String> rules;
  final List<String> buyPropertyTypes;
  final List<String> constructionStatus;
  final String sortBy; // distance, price_asc, price_desc

  const FilterState({
    this.selectedCategory = 'Rental',
    this.minBudget = 0,
    this.maxBudget = 100000,
    this.propertyTypes = const [],
    this.occupancy = const [],
    this.bathrooms = const [],
    this.amenities = const [],
    this.furnishing = const [],
    this.tenants = const [],
    this.bhkTypes = const [],
    this.genderPreference = const [],
    this.foodPreferences = const [],
    this.roomTypes = const [],
    this.parking = const [],
    this.rules = const [],
    this.buyPropertyTypes = const [],
    this.constructionStatus = const [],
    this.sortBy = 'distance',
  });

  int get activeFilterCount {
    int count = 0;
    if (minBudget > 0 || (selectedCategory == 'Buy' ? maxBudget < 50000000 : (selectedCategory == 'PG' ? maxBudget < 35000 : maxBudget < 100000))) count++;
    if (occupancy.isNotEmpty) count++;
    if (bathrooms.isNotEmpty) count++;
    if (amenities.isNotEmpty) count++;
    if (furnishing.isNotEmpty) count++;
    if (tenants.isNotEmpty) count++;
    if (bhkTypes.isNotEmpty) count++;
    if (genderPreference.isNotEmpty) count++;
    if (foodPreferences.isNotEmpty) count++;
    if (roomTypes.isNotEmpty) count++;
    if (parking.isNotEmpty) count++;
    if (rules.isNotEmpty) count++;
    if (buyPropertyTypes.isNotEmpty) count++;
    if (constructionStatus.isNotEmpty) count++;
    if (sortBy != 'distance') count++;
    return count;
  }

  FilterState copyWith({
    String? selectedCategory,
    double? minBudget,
    double? maxBudget,
    List<String>? propertyTypes,
    List<String>? occupancy,
    List<String>? bathrooms,
    List<String>? amenities,
    List<String>? furnishing,
    List<String>? tenants,
    List<String>? bhkTypes,
    List<String>? genderPreference,
    List<String>? foodPreferences,
    List<String>? roomTypes,
    List<String>? parking,
    List<String>? rules,
    List<String>? buyPropertyTypes,
    List<String>? constructionStatus,
    String? sortBy,
  }) {
    return FilterState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      occupancy: occupancy ?? this.occupancy,
      bathrooms: bathrooms ?? this.bathrooms,
      amenities: amenities ?? this.amenities,
      furnishing: furnishing ?? this.furnishing,
      tenants: tenants ?? this.tenants,
      bhkTypes: bhkTypes ?? this.bhkTypes,
      genderPreference: genderPreference ?? this.genderPreference,
      foodPreferences: foodPreferences ?? this.foodPreferences,
      roomTypes: roomTypes ?? this.roomTypes,
      parking: parking ?? this.parking,
      rules: rules ?? this.rules,
      buyPropertyTypes: buyPropertyTypes ?? this.buyPropertyTypes,
      constructionStatus: constructionStatus ?? this.constructionStatus,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final FilterState initialState;
  final String? initialCategory;
  final ValueChanged<FilterState> onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialState,
    this.initialCategory,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterState _state;
  late String _currentCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.initialCategory ??
        (widget.initialState.selectedCategory.isNotEmpty
            ? widget.initialState.selectedCategory
            : 'Rental');
    _state = widget.initialState.copyWith(
      selectedCategory: _currentCategory,
      propertyTypes: [_currentCategory],
    );
  }

  void _onCategoryChanged(String category) {
    if (_currentCategory == category) return;
    HapticFeedback.selectionClick();

    double defaultMax = 100000;
    if (category == 'PG') defaultMax = 35000;
    if (category == 'Buy') defaultMax = 50000000;

    setState(() {
      _currentCategory = category;
      _state = FilterState(
        selectedCategory: category,
        propertyTypes: [category],
        minBudget: 0,
        maxBudget: defaultMax,
        sortBy: _state.sortBy,
      );
    });
  }

  void _clearAllAndClose() {
    HapticFeedback.mediumImpact();
    double defaultMax = 100000;
    if (_currentCategory == 'PG') defaultMax = 35000;
    if (_currentCategory == 'Buy') defaultMax = 50000000;

    final clearedState = FilterState(
      selectedCategory: _currentCategory,
      propertyTypes: [_currentCategory],
      minBudget: 0,
      maxBudget: defaultMax,
      sortBy: 'distance',
    );
    widget.onApply(clearedState);
    Navigator.pop(context);
  }

  void _apply() {
    HapticFeedback.selectionClick();
    widget.onApply(_state);
    Navigator.pop(context);
  }

  void _toggleList(List<String> list, String value, void Function(List<String>) update) {
    HapticFeedback.selectionClick();
    setState(() {
      final newList = List<String>.from(list);
      if (newList.contains(value)) {
        newList.remove(value);
      } else {
        newList.add(value);
      }
      update(newList);
    });
  }

  String _formatBudget(double val, bool isBuy) {
    if (isBuy) {
      if (val >= 10000000) {
        return '₹${(val / 10000000).toStringAsFixed(1)} Cr';
      } else if (val >= 100000) {
        return '₹${(val / 100000).toStringAsFixed(0)} Lakhs';
      }
      return '₹${val.toInt()}';
    } else {
      if (val >= 100000) {
        return '₹1L+';
      } else if (val >= 1000) {
        return '₹${(val / 1000).toStringAsFixed(0)}k';
      }
      return '₹${val.toInt()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = _state.activeFilterCount;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Sort & Filters',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: _clearAllAndClose,
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                      decoration: TextDecoration.underline,
                      decorationColor: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. PRIMARY CATEGORY PICKER (Asked First)
                  _buildSectionHeader('Looking For', subtitle: 'Choose property type to customize filters'),
                  _buildCategorySelector(isDark),
                  const SizedBox(height: 24),

                  // 2. SORT BY
                  _buildSectionHeader('Sort By'),
                  _buildChoiceChips(
                    _currentCategory == 'Buy'
                        ? ['Price: Low to High', 'Price: High to Low', 'Distance']
                        : ['Distance', 'Price: Low to High', 'Price: High to Low'],
                    _state.sortBy == 'distance'
                        ? 'Distance'
                        : (_state.sortBy == 'price_asc'
                            ? 'Price: Low to High'
                            : 'Price: High to Low'),
                    (val) {
                      setState(() {
                        if (val == 'Distance') _state = _state.copyWith(sortBy: 'distance');
                        if (val == 'Price: Low to High') _state = _state.copyWith(sortBy: 'price_asc');
                        if (val == 'Price: High to Low') _state = _state.copyWith(sortBy: 'price_desc');
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. BUDGET RANGE (Dynamic based on category)
                  _buildBudgetSection(isDark),
                  const SizedBox(height: 24),

                  // 4. CATEGORY-SPECIFIC SECTIONS
                  if (_currentCategory == 'Rental') ..._buildRentalSections(isDark),
                  if (_currentCategory == 'PG') ..._buildPgSections(isDark),
                  if (_currentCategory == 'Buy') ..._buildBuySections(isDark),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                activeCount > 0 ? 'Apply Filters ($activeCount)' : 'Show All Properties',
                style: const TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Top Category Selector ──────────────────────────────────────────────
  Widget _buildCategorySelector(bool isDark) {
    final categories = [
      (
        id: 'Rental',
        title: 'Rental Home',
        subtitle: 'House, Flat, Villa',
        icon: CupertinoIcons.house_fill,
      ),
      (
        id: 'PG',
        title: 'PG / Hostel',
        subtitle: 'Coliving & Rooms',
        icon: Iconsax.building,
      ),
      (
        id: 'Buy',
        title: 'Buy Property',
        subtitle: 'Houses & Plots',
        icon: CupertinoIcons.bag_fill,
      ),
    ];

    return Row(
      children: categories.map((cat) {
        final isSelected = _currentCategory == cat.id;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _onCategoryChanged(cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryYellow.withValues(alpha: isDark ? 0.2 : 0.15)
                      : (isDark ? const Color(0xFF282828) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryYellow
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryYellow.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 24,
                      color: isSelected
                          ? (isDark ? AppTheme.primaryYellow : Colors.black87)
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cat.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey.shade300 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? (isDark ? AppTheme.primaryYellow : Colors.grey.shade800)
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 2. Budget Range Slider & Quick Presets ─────────────────────────────────
  Widget _buildBudgetSection(bool isDark) {
    final isBuy = _currentCategory == 'Buy';
    final isPg = _currentCategory == 'PG';

    final double maxPossible = isBuy ? 50000000 : (isPg ? 35000 : 100000);
    final currentMin = _state.minBudget.clamp(0.0, maxPossible);
    final currentMax = _state.maxBudget.clamp(currentMin, maxPossible);

    // Quick presets
    final List<(String, double, double)> presets = isBuy
        ? [
            ('Under ₹30L', 0, 3000000),
            ('₹30L - ₹60L', 3000000, 6000000),
            ('₹60L - ₹1.2 Cr', 6000000, 12000000),
            ('₹1.2 Cr+', 12000000, 50000000),
          ]
        : (isPg
            ? [
                ('Under ₹6k', 0, 6000),
                ('₹6k - ₹10k', 6000, 10000),
                ('₹10k - ₹15k', 10000, 15000),
                ('₹15k+', 15000, 35000),
              ]
            : [
                ('Under ₹10k', 0, 10000),
                ('₹10k - ₹20k', 10000, 20000),
                ('₹20k - ₹40k', 20000, 40000),
                ('₹40k+', 40000, 100000),
              ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(isBuy ? 'Total Budget (₹)' : 'Monthly Rent (₹)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_formatBudget(currentMin, isBuy)} - ${_formatBudget(currentMax, isBuy)}',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.primaryYellow : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((preset) {
              final isPresetActive = (_state.minBudget == preset.$2 && _state.maxBudget == preset.$3);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _state = _state.copyWith(minBudget: preset.$2, maxBudget: preset.$3);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPresetActive
                          ? AppTheme.primaryYellow
                          : (isDark ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPresetActive
                            ? AppTheme.primaryYellow
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      preset.$1,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12,
                        fontWeight: isPresetActive ? FontWeight.w700 : FontWeight.w500,
                        color: isPresetActive
                            ? Colors.black
                            : (isDark ? Colors.grey.shade300 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        RangeSlider(
          values: RangeValues(currentMin, currentMax),
          min: 0,
          max: maxPossible,
          divisions: isBuy ? 50 : (isPg ? 35 : 20),
          activeColor: AppTheme.primaryYellow,
          inactiveColor: isDark ? Colors.white24 : Colors.grey.shade300,
          labels: RangeLabels(
            _formatBudget(currentMin, isBuy),
            _formatBudget(currentMax, isBuy),
          ),
          onChanged: (values) {
            setState(() {
              _state = _state.copyWith(minBudget: values.start, maxBudget: values.end);
            });
          },
        ),
      ],
    );
  }

  // ── 3. Rental Home Sections ───────────────────────────────────────────────
  List<Widget> _buildRentalSections(bool isDark) {
    return [
      _buildSectionHeader('BHK Configuration'),
      _buildMultiChoiceChips(
        ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4+ BHK', 'Villa / House'],
        _state.bhkTypes,
        (val) => _toggleList(_state.bhkTypes, val, (nl) => _state = _state.copyWith(bhkTypes: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Preferred Tenants'),
      _buildMultiChoiceChips(
        ['Family', 'Bachelors', 'Working Professionals', 'Students', 'Anyone'],
        _state.tenants,
        (val) => _toggleList(_state.tenants, val, (nl) => _state = _state.copyWith(tenants: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Furnishing Status'),
      _buildMultiChoiceChips(
        ['Fully Furnished', 'Semi Furnished', 'Unfurnished'],
        _state.furnishing,
        (val) => _toggleList(_state.furnishing, val, (nl) => _state = _state.copyWith(furnishing: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Bathrooms'),
      _buildMultiChoiceChips(
        ['1 Bath', '2 Baths', '3+ Baths', 'Attached Washroom'],
        _state.bathrooms,
        (val) => _toggleList(_state.bathrooms, val, (nl) => _state = _state.copyWith(bathrooms: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Parking'),
      _buildMultiChoiceChips(
        ['Car Parking', 'Bike Parking', 'Covered Parking'],
        _state.parking,
        (val) => _toggleList(_state.parking, val, (nl) => _state = _state.copyWith(parking: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Amenities & Features'),
      _buildMultiChoiceChips(
        [
          'Lift',
          'Power Backup',
          'Gated Security',
          '24/7 Water',
          'Balcony',
          'Pet Friendly',
          'Air Conditioner',
          'Modular Kitchen',
          'CCTV',
        ],
        _state.amenities,
        (val) => _toggleList(_state.amenities, val, (nl) => _state = _state.copyWith(amenities: nl)),
      ),
    ];
  }

  // ── 4. PG / Hostel Sections ───────────────────────────────────────────────
  List<Widget> _buildPgSections(bool isDark) {
    return [
      _buildSectionHeader('Gender Preference', subtitle: 'Hostels / PGs separated by gender'),
      _buildMultiChoiceChips(
        ['Boys Only', 'Girls Only', 'Co-Living / Unisex'],
        _state.genderPreference,
        (val) => _toggleList(_state.genderPreference, val, (nl) => _state = _state.copyWith(genderPreference: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Room Sharing / Occupancy'),
      _buildMultiChoiceChips(
        ['Single (Private)', '2 Sharing', '3 Sharing', '4+ Sharing'],
        _state.occupancy,
        (val) => _toggleList(_state.occupancy, val, (nl) => _state = _state.copyWith(occupancy: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Food & Meals'),
      _buildMultiChoiceChips(
        ['3 Meals Included', '2 Meals Included', 'With Food', 'Self Cooking Allowed'],
        _state.foodPreferences,
        (val) => _toggleList(_state.foodPreferences, val, (nl) => _state = _state.copyWith(foodPreferences: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Room Type & Washroom'),
      _buildMultiChoiceChips(
        ['AC Room', 'Non-AC Room', 'Attached Washroom', 'Common Washroom'],
        _state.roomTypes,
        (val) => _toggleList(_state.roomTypes, val, (nl) => _state = _state.copyWith(roomTypes: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Gate Rules & Curfew'),
      _buildMultiChoiceChips(
        ['No Curfew / 24x7 Entry', 'Flexible Timings', 'Late Entry Allowed'],
        _state.rules,
        (val) => _toggleList(_state.rules, val, (nl) => _state = _state.copyWith(rules: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('PG Amenities'),
      _buildMultiChoiceChips(
        [
          'High-Speed Wi-Fi',
          'Washing Machine',
          'Daily Housekeeping',
          'RO Drinking Water',
          'Geyser',
          'Power Backup',
          'CCTV Security',
          'Individual Locker',
          'Bike Parking',
        ],
        _state.amenities,
        (val) => _toggleList(_state.amenities, val, (nl) => _state = _state.copyWith(amenities: nl)),
      ),
    ];
  }

  // ── 5. Buy Property Sections ──────────────────────────────────────────────
  List<Widget> _buildBuySections(bool isDark) {
    return [
      _buildSectionHeader('Property Type'),
      _buildMultiChoiceChips(
        ['Apartment / Flat', 'Independent House', 'Villa', 'Plot / Land', 'Commercial'],
        _state.buyPropertyTypes,
        (val) => _toggleList(_state.buyPropertyTypes, val, (nl) => _state = _state.copyWith(buyPropertyTypes: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('BHK / Bedrooms'),
      _buildMultiChoiceChips(
        ['1 BHK', '2 BHK', '3 BHK', '4+ BHK', 'Duplex / Penthouse'],
        _state.bhkTypes,
        (val) => _toggleList(_state.bhkTypes, val, (nl) => _state = _state.copyWith(bhkTypes: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Possession / Status'),
      _buildMultiChoiceChips(
        ['Ready to Move', 'Under Construction', 'New Launch'],
        _state.constructionStatus,
        (val) => _toggleList(_state.constructionStatus, val, (nl) => _state = _state.copyWith(constructionStatus: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Furnishing Status'),
      _buildMultiChoiceChips(
        ['Unfurnished', 'Semi Furnished', 'Fully Furnished'],
        _state.furnishing,
        (val) => _toggleList(_state.furnishing, val, (nl) => _state = _state.copyWith(furnishing: nl)),
      ),
      const SizedBox(height: 24),

      _buildSectionHeader('Community & Society Amenities'),
      _buildMultiChoiceChips(
        [
          'Gated Community',
          'Lift',
          'Covered Car Parking',
          'Club House',
          'Swimming Pool',
          'Power Backup',
          '24/7 Security',
          'Park / Play Area',
          'Gym',
        ],
        _state.amenities,
        (val) => _toggleList(_state.amenities, val, (nl) => _state = _state.copyWith(amenities: nl)),
      ),
    ];
  }

  // ── Section Header Helper ─────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Choice Chips Helper ───────────────────────────────────────────────────
  Widget _buildChoiceChips(List<String> options, String selectedValue, ValueChanged<String> onSelected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValue == option;
        return _buildChip(option, isSelected, () => onSelected(option));
      }).toList(),
    );
  }

  // ── Multi Choice Chips Helper ─────────────────────────────────────────────
  Widget _buildMultiChoiceChips(List<String> options, List<String> selectedValues, ValueChanged<String> onSelected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValues.contains(option);
        return _buildChip(option, isSelected, () => onSelected(option));
      }).toList(),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedBg = AppTheme.primaryYellow;
    const selectedText = Colors.black;
    final selectedBorder = AppTheme.primaryYellow;

    final unselectedBg = isDark ? const Color(0xFF282828) : Colors.white;
    final unselectedText = isDark ? Colors.grey.shade300 : Colors.black87;
    final unselectedBorder = isDark ? Colors.white12 : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedBorder : unselectedBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}
