import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';
import 'home_screen.dart' show PropertyModel, PropertyCard;
import 'property_details_screen.dart';
import 'ai_chat_screen.dart';

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
  final FocusNode _focusNode = FocusNode();

  // Active Filter States
  String _selectedCategory = 'All'; // 'All', 'Flat', 'House', 'PG', 'Office', 'Land', 'Buy'
  String? _selectedLocation; // e.g. 'Hyderabad', 'Visakhapatnam'
  RangeValues _budgetRange = const RangeValues(0, 10000000); // ₹0 - ₹1 Cr
  String? _selectedBhk; // '1 BHK', '2 BHK', '3 BHK', '4+ BHK'
  String? _selectedBathrooms; // '1+ Bath', '2+ Bath', '3+ Bath', '4+ Bath'
  String? _selectedSharing; // 'Single Room', '2 Sharing', '3 Sharing', '4+ Sharing'
  String? _selectedGender; // 'Boys Only', 'Girls Only', 'Co-Living'
  final Set<String> _selectedAmenities = {}; // 'Parking', 'Power Backup', 'Lift', 'AC', 'Food', 'WiFi', 'Geyser', 'CCTV', 'Attached Bath'
  String? _selectedFurnishing; // 'Fully Furnished', 'Semi Furnished', 'Unfurnished'
  String? _selectedTenant; // 'Any', 'Bachelors', 'Family', 'Company'
  String? _selectedAvailability; // 'Immediately', 'Within 1 Month', '1-3 Months'
  String? _selectedFoodType; // '3 Meals', '2 Meals', 'Veg Only', 'Self Cooking'
  String? _selectedCurfew; // 'No Curfew', 'Gate Closes 10:30 PM'
  bool _petFriendly = false;
  bool _separateMeter = false;
  bool _zeroSeepage = false;
  RangeValues _areaRange = const RangeValues(0, 10000); // 0 - 10,000 sqft
  String _sortBy = 'relevance'; // 'relevance', 'distance', 'price_asc', 'price_desc'

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _selectedCategory != 'All' ||
      _selectedLocation != null ||
      _budgetRange.start > 0 ||
      _budgetRange.end < 10000000 ||
      _selectedBhk != null ||
      _selectedBathrooms != null ||
      _selectedSharing != null ||
      _selectedGender != null ||
      _selectedAmenities.isNotEmpty ||
      _selectedFurnishing != null ||
      _selectedTenant != null ||
      _selectedAvailability != null ||
      _selectedFoodType != null ||
      _selectedCurfew != null ||
      _petFriendly ||
      _separateMeter ||
      _zeroSeepage ||
      _areaRange.start > 0 ||
      _areaRange.end < 10000;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_selectedLocation != null) count++;
    if (_budgetRange.start > 0 || _budgetRange.end < 10000000) count++;
    if (_selectedBhk != null) count++;
    if (_selectedBathrooms != null) count++;
    if (_selectedSharing != null) count++;
    if (_selectedGender != null) count++;
    if (_selectedAmenities.isNotEmpty) count += _selectedAmenities.length;
    if (_selectedFurnishing != null) count++;
    if (_selectedTenant != null) count++;
    if (_selectedAvailability != null) count++;
    if (_selectedFoodType != null) count++;
    if (_selectedCurfew != null) count++;
    if (_petFriendly) count++;
    if (_separateMeter) count++;
    if (_zeroSeepage) count++;
    if (_areaRange.start > 0 || _areaRange.end < 10000) count++;
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

  double _parseArea(String areaStr) {
    try {
      final clean = areaStr.replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse(clean) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  int _parseBaths(String bathsStr) {
    try {
      final clean = bathsStr.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(clean) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  List<PropertyModel> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();

    List<PropertyModel> list = widget.properties.where((p) {
      final t = p.type.toLowerCase().trim();
      final title = p.title.toLowerCase().trim();
      final desc = (p.description ?? '').toLowerCase().trim();

      // 1. Property Type Category
      if (_selectedCategory == 'PG') {
        final isPg = t == 'pg' ||
            t == 'hostel' ||
            t.contains('pg') ||
            t.contains('hostel') ||
            t.contains('co-living') ||
            title.contains('pg') ||
            title.contains('hostel') ||
            desc.contains('pg') ||
            desc.contains('hostel') ||
            (p.genderPreference != null && p.genderPreference!.isNotEmpty) ||
            (p.sharingType != null && p.sharingType!.isNotEmpty) ||
            (p.foodDetails != null && p.foodDetails!.isNotEmpty) ||
            p.perDayWithFood != null;
        if (!isPg) return false;
      } else if (_selectedCategory == 'Flat') {
        final isFlat = (t == 'rental' || t == 'flat' || t == 'apartment') &&
            (title.contains('flat') || title.contains('apartment') || (p.bhkType?.toLowerCase().contains('bhk') ?? false));
        if (!isFlat) return false;
      } else if (_selectedCategory == 'House') {
        final isHouse = (t == 'rental' || t == 'house' || t == 'villa') &&
            (title.contains('house') || title.contains('villa') || title.contains('independent') || t == 'rental');
        if (!isHouse) return false;
      } else if (_selectedCategory == 'Buy') {
        final isBuy = t == 'buy' || t == 'sale' || t == 'plot' || t == 'land' || title.contains('sale') || title.contains('buy');
        if (!isBuy) return false;
      } else if (_selectedCategory == 'Office') {
        final isOff = title.contains('office') || title.contains('commercial') || t.contains('commercial');
        if (!isOff) return false;
      } else if (_selectedCategory == 'Land') {
        final isLand = title.contains('plot') || title.contains('land') || t == 'plot';
        if (!isLand) return false;
      }

      // 2. Location filter
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty && _selectedLocation != 'All Locations') {
        final loc = _selectedLocation!.toLowerCase();
        if (!p.locationStr.toLowerCase().contains(loc) && !title.contains(loc)) {
          return false;
        }
      }

      // 3. Budget Range
      final price = _parsePrice(p.price);
      if (price > 0) {
        if (price < _budgetRange.start || price > _budgetRange.end) {
          return false;
        }
      }

      // 4. BHK Filter (Only for Flats / Houses / Rentals)
      if (_selectedBhk != null && _selectedCategory != 'PG') {
        final b = _selectedBhk!.toLowerCase();
        if (b.contains('1') && !p.beds.toLowerCase().contains('1') && !(p.bhkType?.toLowerCase().contains('1') ?? false)) {
          return false;
        } else if (b.contains('2') && !p.beds.toLowerCase().contains('2') && !(p.bhkType?.toLowerCase().contains('2') ?? false)) {
          return false;
        } else if (b.contains('3') && !p.beds.toLowerCase().contains('3') && !(p.bhkType?.toLowerCase().contains('3') ?? false)) {
          return false;
        } else if (b.contains('4')) {
          final bedsStr = p.beds.toLowerCase();
          if (!bedsStr.contains('4') && !bedsStr.contains('5') && !(p.bhkType?.toLowerCase().contains('4') ?? false)) {
            return false;
          }
        }
      }

      // 5. Bathrooms
      if (_selectedBathrooms != null && _selectedCategory != 'PG') {
        final reqBaths = int.tryParse(_selectedBathrooms!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        final propBaths = _parseBaths(p.baths);
        if (propBaths < reqBaths) return false;
      }

      // 6. Sharing Type (PG/Hostel)
      if (_selectedSharing != null) {
        final sh = (p.sharingType ?? p.beds).toLowerCase();
        if (_selectedSharing == 'Single Room' && !sh.contains('single') && !sh.contains('1')) return false;
        if (_selectedSharing == '2 Sharing' && !sh.contains('2')) return false;
        if (_selectedSharing == '3 Sharing' && !sh.contains('3')) return false;
        if (_selectedSharing == '4+ Sharing' && !sh.contains('4') && !sh.contains('5')) return false;
      }

      // 7. Gender Preference (Hostel/PG)
      if (_selectedGender != null) {
        final g = (p.genderPreference ?? '').toLowerCase();
        if (_selectedGender == 'Boys Only' && !g.contains('boy') && !g.contains('male')) return false;
        if (_selectedGender == 'Girls Only' && !g.contains('girl') && !g.contains('female') && !g.contains('women')) return false;
        if (_selectedGender == 'Co-Living' && !g.contains('co-living') && !g.contains('coliving') && !g.contains('any')) return false;
      }

      // 8. Food Type (Hostel/PG)
      if (_selectedFoodType != null) {
        final fd = (p.foodDetails ?? '').toLowerCase();
        if (_selectedFoodType == '3 Meals' && !fd.contains('3')) return false;
        if (_selectedFoodType == '2 Meals' && !fd.contains('2')) return false;
        if (_selectedFoodType == 'Veg Only' && !fd.contains('veg')) return false;
        if (_selectedFoodType == 'Self Cooking' && !fd.contains('self') && !fd.contains('cook')) return false;
      }

      // 9. Gate Rules / Curfew
      if (_selectedCurfew != null) {
        final gr = (p.gateRules ?? '').toLowerCase();
        if (_selectedCurfew == 'No Curfew' && !gr.contains('no curfew') && !gr.contains('24')) return false;
      }

      // 10. Rental Features: Pet friendly, Separate Meter, Zero Seepage
      if (_petFriendly) {
        final pet = (p.petPolicy ?? '').toLowerCase();
        if (!pet.contains('pet') || pet.contains('no pet')) return false;
      }
      if (_separateMeter) {
        final mtr = (p.meterStatus ?? '').toLowerCase();
        if (!mtr.contains('meter') && !mtr.contains('eb')) return false;
      }
      if (_zeroSeepage) {
        final sep = (p.seepageStatus ?? '').toLowerCase();
        if (!sep.contains('seepage') && !sep.contains('paint')) return false;
      }

      // 11. Amenities
      for (var amenity in _selectedAmenities) {
        if (amenity == 'Parking') {
          final hasP = (p.parkingInfo ?? '').isNotEmpty || p.features.any((f) => f.toLowerCase().contains('park'));
          if (!hasP) return false;
        } else if (amenity == 'Power Backup') {
          final hasPb = (p.powerBackup ?? '').isNotEmpty || p.features.any((f) => f.toLowerCase().contains('power') || f.toLowerCase().contains('inverter'));
          if (!hasPb) return false;
        } else if (amenity == 'Lift') {
          final hasLift = p.features.any((f) => f.toLowerCase().contains('lift') || f.toLowerCase().contains('elevator'));
          if (!hasLift) return false;
        } else if (amenity == 'AC') {
          final hasAc = (p.acType ?? '').toLowerCase().contains('ac') || p.features.any((f) => f.toLowerCase().contains('ac'));
          if (!hasAc) return false;
        } else if (amenity == 'Food') {
          final hasFood = (p.foodDetails ?? '').isNotEmpty || p.perDayWithFood != null;
          if (!hasFood) return false;
        } else if (amenity == 'WiFi') {
          final hasWifi = p.features.any((f) => f.toLowerCase().contains('wifi') || f.toLowerCase().contains('internet'));
          if (!hasWifi) return false;
        } else if (amenity == 'Geyser') {
          final hasG = p.features.any((f) => f.toLowerCase().contains('geyser') || f.toLowerCase().contains('hot water'));
          if (!hasG) return false;
        } else if (amenity == 'CCTV') {
          final hasC = (p.securityInfo ?? '').toLowerCase().contains('cctv') || p.features.any((f) => f.toLowerCase().contains('cctv') || f.toLowerCase().contains('guard'));
          if (!hasC) return false;
        } else if (amenity == 'Attached Bath') {
          final hasB = (p.bathroomType ?? '').toLowerCase().contains('attached') || p.features.any((f) => f.toLowerCase().contains('attached'));
          if (!hasB) return false;
        }
      }

      // 12. Furnishing Status
      if (_selectedFurnishing != null) {
        final f = (p.furnishingStatus ?? '').toLowerCase();
        if (_selectedFurnishing == 'Fully Furnished' && !f.contains('fully')) return false;
        if (_selectedFurnishing == 'Semi Furnished' && !f.contains('semi')) return false;
        if (_selectedFurnishing == 'Unfurnished' && (!f.contains('unfurnished') && f.isNotEmpty)) return false;
      }

      // 13. Preferred Tenants
      if (_selectedTenant != null && _selectedTenant != 'Any') {
        final ten = (p.tenantPreference ?? p.genderPreference ?? '').toLowerCase();
        if (_selectedTenant == 'Bachelors' && !ten.contains('bachelor') && !ten.contains('boys') && !ten.contains('girls') && !ten.contains('any')) return false;
        if (_selectedTenant == 'Family' && !ten.contains('family') && !ten.contains('any')) return false;
        if (_selectedTenant == 'Company' && !ten.contains('company') && !ten.contains('commercial')) return false;
      }

      // 14. Area Range
      if (_areaRange.start > 0 || _areaRange.end < 10000) {
        final areaVal = _parseArea(p.area);
        if (areaVal > 0 && (areaVal < _areaRange.start || areaVal > _areaRange.end)) return false;
      }

      // 15. Text query filter
      if (query.isEmpty) return true;

      final titleMatch = title.contains(query);
      final locationMatch = p.locationStr.toLowerCase().contains(query);
      final priceMatch = p.price.toLowerCase().contains(query);
      final bedsMatch = p.beds.toLowerCase().contains(query);
      final typeMatch = t.contains(query);
      final bhkMatch = (p.bhkType ?? '').toLowerCase().contains(query);
      final featuresMatch = p.features.any((f) => f.toLowerCase().contains(query));
      final tagsMatch = p.tags.any((tItem) => tItem.toLowerCase().contains(query));

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



  String _formatBudgetLabel(double value) {
    if (value <= 0) return '₹0';
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(value % 10000000 == 0 ? 0 : 1)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)} Lakh';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}K';
    }
    return '₹${value.toStringAsFixed(0)}';
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = _filteredProperties;
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Row 1: Clean Top Bar [Back] - [Search Properties • City] - [Filter Button]
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: _buildTopBar(isDark),
            ),

            // Row 2: Clean Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSearchBar(isDark),
            ),

            const SizedBox(height: 8),

            // Row 3: Quick Category Pills
            _buildCategoryPills(isDark),

            // Row 4: Active Filter Badges (if any)
            if (_hasActiveFilters)
              _buildActiveFilterChips(isDark),

            // Row 5: Results Count & Clean Sort Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${results.length} ${results.length == 1 ? 'property' : 'properties'} found',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                  _buildSortButton(isDark),
                ],
              ),
            ),

            // Main Content: Property Cards List OR Clean Empty State
            Expanded(
              child: results.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: results.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final prop = results[index];
                        double? distance;
                        if (widget.currentPosition != null) {
                          distance = Geolocator.distanceBetween(
                            widget.currentPosition!.latitude,
                            widget.currentPosition!.longitude,
                            prop.latitude,
                            prop.longitude,
                          );
                        }
                        return PropertyCard(
                          property: prop,
                          distanceInMeters: distance,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PropertyDetailsScreen(property: prop),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: BouncingButton(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiChatScreen(initialProperties: widget.properties),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isDark ? const Color(0xFFF59E0B) : Colors.black).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.magic_star,
                size: 16,
                color: isDark ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 7),
              Text(
                'Ask Rental AI',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Row: Back Button on Left, Title in Center, Filter Button on Right
  Widget _buildTopBar(bool isDark) {
    final hasFilters = _hasActiveFilters;
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back Button
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Iconsax.arrow_left_2,
              color: primaryTextColor,
              size: 18,
            ),
          ),
        ),

        // Title: Search Properties
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Search Properties',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Rajamahendravaram',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: mutedColor,
              ),
            ),
          ],
        ),

        // Filter Icon Button (Top Right)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            _openAdvancedFiltersSheet();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hasFilters
                      ? const Color(0xFFF59E0B)
                      : (isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasFilters
                        ? const Color(0xFFF59E0B)
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Iconsax.setting_4,
                  size: 18,
                  color: hasFilters ? Colors.black : primaryTextColor,
                ),
              ),
              if (hasFilters)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_activeFilterCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Second Row: Clean Search Input Bar
  Widget _buildSearchBar(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.search_normal_1,
            size: 17,
            color: mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search city, area, 2 BHK, hostel, buy...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: mutedColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
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
                  size: 17,
                  color: mutedColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Quick Category Pills (Horizontal Scroll)
  Widget _buildCategoryPills(bool isDark) {
    final categories = const [
      {'name': 'All', 'icon': Iconsax.category},
      {'name': 'Flat', 'icon': Iconsax.buildings},
      {'name': 'House', 'icon': Iconsax.home_2},
      {'name': 'PG', 'icon': Iconsax.user_tag},
      {'name': 'Office', 'icon': Iconsax.shop},
      {'name': 'Land', 'icon': Iconsax.map_1},
      {'name': 'Buy', 'icon': Iconsax.key},
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final name = cat['name'] as String;
          final icon = cat['icon'] as IconData;
          final isSelected = _selectedCategory == name;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = name);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF1E2330) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    name == 'PG' ? 'PG / Hostel' : (name == 'Office' ? 'Commercial' : name),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Active Filters Removable Chips
  Widget _buildActiveFilterChips(bool isDark) {
    final chips = <Map<String, dynamic>>[];

    if (_selectedCategory != 'All') {
      chips.add({
        'label': _selectedCategory,
        'onRemove': () => setState(() => _selectedCategory = 'All'),
      });
    }
    if (_selectedLocation != null) {
      chips.add({
        'label': _selectedLocation!,
        'onRemove': () => setState(() => _selectedLocation = null),
      });
    }
    if (_selectedBhk != null) {
      chips.add({
        'label': _selectedBhk!,
        'onRemove': () => setState(() => _selectedBhk = null),
      });
    }
    if (_selectedFurnishing != null) {
      chips.add({
        'label': _selectedFurnishing!,
        'onRemove': () => setState(() => _selectedFurnishing = null),
      });
    }
    if (_selectedTenant != null) {
      chips.add({
        'label': _selectedTenant!,
        'onRemove': () => setState(() => _selectedTenant = null),
      });
    }
    if (_selectedSharing != null) {
      chips.add({
        'label': _selectedSharing!,
        'onRemove': () => setState(() => _selectedSharing = null),
      });
    }
    if (_selectedGender != null) {
      chips.add({
        'label': _selectedGender!,
        'onRemove': () => setState(() => _selectedGender = null),
      });
    }
    for (final a in _selectedAmenities) {
      chips.add({
        'label': a,
        'onRemove': () => setState(() => _selectedAmenities.remove(a)),
      });
    }
    if (_budgetRange.start > 0 || _budgetRange.end < 10000000) {
      chips.add({
        'label': '${_formatBudgetLabel(_budgetRange.start)} - ${_formatBudgetLabel(_budgetRange.end)}',
        'onRemove': () => setState(() => _budgetRange = const RangeValues(0, 10000000)),
      });
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SizedBox(
        height: 26,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ...chips.map((c) {
              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252B3B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: c['onRemove'] as VoidCallback,
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              );
            }),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = 'All';
                  _selectedLocation = null;
                  _budgetRange = const RangeValues(0, 10000000);
                  _selectedBhk = null;
                  _selectedBathrooms = null;
                  _selectedSharing = null;
                  _selectedGender = null;
                  _selectedAmenities.clear();
                  _selectedFurnishing = null;
                  _selectedTenant = null;
                  _selectedAvailability = null;
                  _selectedFoodType = null;
                  _selectedCurfew = null;
                  _petFriendly = false;
                  _separateMeter = false;
                  _zeroSeepage = false;
                  _areaRange = const RangeValues(0, 10000);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Text(
                  'Clear all',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sort Selector Pill
  Widget _buildSortButton(bool isDark) {
    String label = 'Relevance';
    if (_sortBy == 'price_asc') label = 'Price: Low';
    if (_sortBy == 'price_desc') label = 'Price: High';
    if (_sortBy == 'distance') label = 'Closest';

    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _showSortBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2330) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.sort,
              size: 13,
              color: mutedColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: mutedColor,
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
      backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Sort Results By',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
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
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: isSelected
          ? (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9))
          : Colors.transparent,
      leading: Icon(
        icon,
        size: 18,
        color: isSelected
            ? const Color(0xFFF59E0B)
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: Color(0xFFF59E0B), size: 18)
          : null,
      onTap: () {
        setState(() => _sortBy = key);
        Navigator.pop(context);
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADVANCED FILTERS MODAL (MATCHING UPLOADED USER SCREENSHOTS)
  // ══════════════════════════════════════════════════════════════════════════
  void _openAdvancedFiltersSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String tempCategory = _selectedCategory;
    String? tempLocation = _selectedLocation;
    RangeValues tempBudget = _budgetRange;
    String? tempBhk = _selectedBhk;
    String? tempBath = _selectedBathrooms;
    String? tempSharing = _selectedSharing;
    String? tempGender = _selectedGender;
    final Set<String> tempAmenities = Set.from(_selectedAmenities);
    String? tempFurnishing = _selectedFurnishing;
    String? tempTenant = _selectedTenant;
    String? tempAvailability = _selectedAvailability;
    String? tempFoodType = _selectedFoodType;
    String? tempCurfew = _selectedCurfew;
    bool tempPet = _petFriendly;
    bool tempMeter = _separateMeter;
    bool tempSeepage = _zeroSeepage;
    RangeValues tempArea = _areaRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Top Navigation Header: [ <- ]   Filters   Reset (No divider line)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back / Close Icon
                        BouncingButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Iconsax.arrow_left_2,
                              size: 22,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),

                        // Title
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),

                        // Reset Action
                        GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              tempCategory = 'All';
                              tempLocation = null;
                              tempBudget = const RangeValues(0, 10000000);
                              tempBhk = null;
                              tempBath = null;
                              tempSharing = null;
                              tempGender = null;
                              tempAmenities.clear();
                              tempFurnishing = null;
                              tempTenant = null;
                              tempAvailability = null;
                              tempFoodType = null;
                              tempCurfew = null;
                              tempPet = false;
                              tempMeter = false;
                              tempSeepage = false;
                              tempArea = const RangeValues(0, 10000);
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Filter Sections
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      children: [
                        // 1. LOCATION DROPDOWN
                        _buildSectionHeader('Location'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openLocationPickerSheet(context, (loc) {
                            setSheetState(() => tempLocation = loc);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tempLocation ?? 'Select location',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: tempLocation != null ? FontWeight.w700 : FontWeight.normal,
                                    color: tempLocation != null
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : (isDark ? Colors.white54 : Colors.grey.shade500),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 2. BUDGET RANGE SLIDER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader('Budget Range'),
                            Text(
                              '${_formatBudgetLabel(tempBudget.start)} – ${_formatBudgetLabel(tempBudget.end)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.primaryYellow : const Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RangeSlider(
                          values: tempBudget,
                          min: 0,
                          max: 10000000,
                          divisions: 100,
                          activeColor: isDark ? AppTheme.primaryYellow : const Color(0xFFFFD600),
                          inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
                          onChanged: (vals) {
                            setSheetState(() => tempBudget = vals);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('₹0', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
                              Text('₹1 Cr', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 3. PROPERTY TYPE CHIPS
                        _buildSectionHeader('Property Type'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            {'label': 'All Properties', 'key': 'All'},
                            {'label': 'Hostel / PG', 'key': 'PG'},
                            {'label': 'Flat / Apartment', 'key': 'Flat'},
                            {'label': 'House / Villa', 'key': 'House'},
                            {'label': 'Buy / Sale', 'key': 'Buy'},
                            {'label': 'Office Space', 'key': 'Office'},
                            {'label': 'Land / Plot', 'key': 'Land'},
                          ].map((item) {
                            final isSel = tempCategory == item['key'];
                            return _buildFilterChip(
                              label: item['label'] as String,
                              isSelected: isSel,
                              isDark: isDark,
                              onTap: () {
                                setSheetState(() => tempCategory = item['key'] as String);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),

                        // 4. OCCUPANCY TYPE (BHK) - Show for general / rentals
                        if (tempCategory != 'PG') ...[
                          _buildSectionHeader('Occupancy Type (BHK)'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['1 BHK', '2 BHK', '3 BHK', '4+ BHK'].map((bhk) {
                              final isSel = tempBhk == bhk;
                              return _buildFilterChip(
                                label: bhk,
                                isSelected: isSel,
                                isDark: isDark,
                                onTap: () {
                                  setSheetState(() => tempBhk = isSel ? null : bhk);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 22),

                          // 5. BATHROOMS
                          _buildSectionHeader('Bathrooms'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['1+ Bath', '2+ Bath', '3+ Bath', '4+ Bath'].map((bath) {
                              final isSel = tempBath == bath;
                              return _buildFilterChip(
                                label: bath,
                                isSelected: isSel,
                                isDark: isDark,
                                onTap: () {
                                  setSheetState(() => tempBath = isSel ? null : bath);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 22),
                        ],

                        // 6. GROUPED CARD (Amenities, Furnishing, Tenants, Availability & Specifics)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : const Color(0xFFF9F9FC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Amenities
                              _buildSubHeader('Amenities & Features'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  {'label': 'Parking', 'key': 'Parking'},
                                  {'label': 'Power Backup', 'key': 'Power Backup'},
                                  {'label': 'Lift / Elevator', 'key': 'Lift'},
                                  {'label': 'AC Rooms', 'key': 'AC'},
                                  {'label': 'Food / Meals Included', 'key': 'Food'},
                                  {'label': 'High Speed WiFi', 'key': 'WiFi'},
                                  {'label': 'Attached Bath', 'key': 'Attached Bath'},
                                  {'label': 'Hot Water / Geyser', 'key': 'Geyser'},
                                  {'label': '24/7 CCTV & Security', 'key': 'CCTV'},
                                ].map((am) {
                                  final isSel = tempAmenities.contains(am['key']);
                                  return _buildFilterChip(
                                    label: am['label'] as String,
                                    isSelected: isSel,
                                    isDark: isDark,
                                    isMulti: true,
                                    onTap: () {
                                      setSheetState(() {
                                        if (isSel) {
                                          tempAmenities.remove(am['key']);
                                        } else {
                                          tempAmenities.add(am['key'] as String);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),

                              // Hostel / PG Specifics: Sharing & Gender & Food
                              _buildSubHeader('Hostel & PG Preferences'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Gender
                                  ...['Boys Only', 'Girls Only', 'Co-Living'].map((g) {
                                    final isSel = tempGender == g;
                                    return _buildFilterChip(
                                      label: g,
                                      isSelected: isSel,
                                      isDark: isDark,
                                      onTap: () => setSheetState(() => tempGender = isSel ? null : g),
                                    );
                                  }),
                                  // Sharing
                                  ...['Single Room', '2 Sharing', '3 Sharing', '4+ Sharing'].map((sh) {
                                    final isSel = tempSharing == sh;
                                    return _buildFilterChip(
                                      label: sh,
                                      isSelected: isSel,
                                      isDark: isDark,
                                      onTap: () => setSheetState(() => tempSharing = isSel ? null : sh),
                                    );
                                  }),
                                  // Food
                                  ...['3 Meals', '2 Meals', 'Veg Only', 'Self Cooking'].map((fd) {
                                    final isSel = tempFoodType == fd;
                                    return _buildFilterChip(
                                      label: fd,
                                      isSelected: isSel,
                                      isDark: isDark,
                                      onTap: () => setSheetState(() => tempFoodType = isSel ? null : fd),
                                    );
                                  }),
                                  // Curfew
                                  _buildFilterChip(
                                    label: 'No Curfew (24x7 Entry)',
                                    isSelected: tempCurfew == 'No Curfew',
                                    isDark: isDark,
                                    onTap: () => setSheetState(() => tempCurfew = tempCurfew == 'No Curfew' ? null : 'No Curfew'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),

                              // Furnishing Status
                              _buildSubHeader('Furnishing Status'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['Fully Furnished', 'Semi Furnished', 'Unfurnished'].map((furn) {
                                  final isSel = tempFurnishing == furn;
                                  return _buildFilterChip(
                                    label: furn,
                                    isSelected: isSel,
                                    isDark: isDark,
                                    onTap: () {
                                      setSheetState(() => tempFurnishing = isSel ? null : furn);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),

                              // Preferred Tenants
                              _buildSubHeader('Preferred Tenants'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['Any', 'Bachelors', 'Family', 'Company'].map((ten) {
                                  final isSel = tempTenant == ten;
                                  return _buildFilterChip(
                                    label: ten,
                                    isSelected: isSel,
                                    isDark: isDark,
                                    onTap: () {
                                      setSheetState(() => tempTenant = isSel ? null : ten);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),

                              // Available From
                              _buildSubHeader('Available From'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['Immediately', 'Within 1 Month', '1-3 Months', '3-6 Months', '6 Months+'].map((av) {
                                  final isSel = tempAvailability == av;
                                  return _buildFilterChip(
                                    label: av,
                                    isSelected: isSel,
                                    isDark: isDark,
                                    onTap: () {
                                      setSheetState(() => tempAvailability = isSel ? null : av);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),

                              // House / Rental Specifics (Pets, Sub-meter, Paint)
                              _buildSubHeader('House & Rental Specifics'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFilterChip(
                                    label: 'Pets Allowed 🐾',
                                    isSelected: tempPet,
                                    isDark: isDark,
                                    isMulti: true,
                                    onTap: () => setSheetState(() => tempPet = !tempPet),
                                  ),
                                  _buildFilterChip(
                                    label: 'Separate EB Sub-Meter ⚡',
                                    isSelected: tempMeter,
                                    isDark: isDark,
                                    isMulti: true,
                                    onTap: () => setSheetState(() => tempMeter = !tempMeter),
                                  ),
                                  _buildFilterChip(
                                    label: 'Zero Seepage / Fresh Paint 🎨',
                                    isSelected: tempSeepage,
                                    isDark: isDark,
                                    isMulti: true,
                                    onTap: () => setSheetState(() => tempSeepage = !tempSeepage),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 7. COVERED AREA (SQFT)
                        if (tempCategory != 'PG') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('Covered Area (Sqft)'),
                              Text(
                                '${tempArea.start.round()} sqft – ${tempArea.end.round()} sqft',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppTheme.primaryYellow : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          RangeSlider(
                            values: tempArea,
                            min: 0,
                            max: 10000,
                            divisions: 50,
                            activeColor: isDark ? AppTheme.primaryYellow : const Color(0xFFFFD600),
                            inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
                            onChanged: (vals) {
                              setSheetState(() => tempArea = vals);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('0 sqft', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
                                Text('10,000 sqft', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),

                  // Bottom Pinned Actions: [ Cancel ]   [ Apply ]
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141416) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Cancel Button
                        Expanded(
                          child: BouncingButton(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Apply Button
                        Expanded(
                          child: BouncingButton(
                            onTap: () {
                              setState(() {
                                _selectedCategory = tempCategory;
                                _selectedLocation = tempLocation;
                                _budgetRange = tempBudget;
                                _selectedBhk = tempBhk;
                                _selectedBathrooms = tempBath;
                                _selectedSharing = tempSharing;
                                _selectedGender = tempGender;
                                _selectedAmenities.clear();
                                _selectedAmenities.addAll(tempAmenities);
                                _selectedFurnishing = tempFurnishing;
                                _selectedTenant = tempTenant;
                                _selectedAvailability = tempAvailability;
                                _selectedFoodType = tempFoodType;
                                _selectedCurfew = tempCurfew;
                                _petFriendly = tempPet;
                                _separateMeter = tempMeter;
                                _zeroSeepage = tempSeepage;
                                _areaRange = tempArea;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.primaryYellow : const Color(0xFFFFEB3A),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? AppTheme.primaryYellow : const Color(0xFFFFEB3A)).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Apply',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
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
            );
          },
        );
      },
    );
  }

  /// Location Sub-Sheet modal
  void _openLocationPickerSheet(BuildContext context, Function(String?) onSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locController = TextEditingController();

    final popularCities = [
      'Visakhapatnam',
      'Hyderabad',
      'Madhapur',
      'Gachibowli',
      'Banjara Hills',
      'Vijayawada',
      'Bengaluru',
      'Chennai',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Search Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: locController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type location (e.g. Visakhapatnam)',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      onSelected(val.trim());
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Action Options: Use Current Location
              if (widget.currentPosition != null)
                ListTile(
                  leading: const Icon(Iconsax.gps, color: Color(0xFFFFD600)),
                  title: const Text('Use current location', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    onSelected('Near My Location');
                    Navigator.pop(ctx);
                  },
                ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Popular Locations',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: popularCities.map((city) {
                  return GestureDetector(
                    onTap: () {
                      onSelected(city);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : const Color(0xFFF0F0F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    bool isMulti = false,
  }) {
    return BouncingButton(
      scaleFactor: 0.97,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2B2800) : const Color(0xFFFFFDE7))
              : (isDark ? AppTheme.darkCardElevated : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.primaryYellow : Colors.black)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? AppTheme.primaryYellow : Colors.black).withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Iconsax.tick_circle
                  : (isMulti ? Iconsax.add_circle : Icons.radio_button_unchecked),
              size: 15,
              color: isSelected
                  ? (isDark ? AppTheme.primaryYellow : Colors.black)
                  : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? AppTheme.primaryYellow : Colors.black)
                    : (isDark ? Colors.white70 : const Color(0xFF2D2D2D)),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty State with Centered Lottie Animation
  Widget _buildEmptyState(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/Nothing founded.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Iconsax.search_status,
                size: 80,
                color: mutedColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No properties found',
              style: GoogleFonts.inter(
                color: primaryTextColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search query or removing filters to discover more properties.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: mutedColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _searchController.clear();
                  _selectedCategory = 'All';
                  _selectedLocation = null;
                  _budgetRange = const RangeValues(0, 10000000);
                  _selectedBhk = null;
                  _selectedBathrooms = null;
                  _selectedSharing = null;
                  _selectedGender = null;
                  _selectedAmenities.clear();
                  _selectedFurnishing = null;
                  _selectedTenant = null;
                  _selectedAvailability = null;
                  _selectedFoodType = null;
                  _selectedCurfew = null;
                  _petFriendly = false;
                  _separateMeter = false;
                  _zeroSeepage = false;
                  _areaRange = const RangeValues(0, 10000);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? const Color(0xFFF59E0B) : Colors.black).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Reset All Filters',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.black : Colors.white,
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
