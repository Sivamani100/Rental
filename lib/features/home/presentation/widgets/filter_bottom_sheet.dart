import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';

class FilterState {
  final double minBudget;
  final double maxBudget;
  final List<String> propertyTypes;
  final List<String> occupancy;
  final List<String> bathrooms;
  final List<String> amenities;
  final List<String> furnishing;
  final List<String> tenants;
  final String sortBy; // distance, price_asc, price_desc

  const FilterState({
    this.minBudget = 0,
    this.maxBudget = 100000,
    this.propertyTypes = const [],
    this.occupancy = const [],
    this.bathrooms = const [],
    this.amenities = const [],
    this.furnishing = const [],
    this.tenants = const [],
    this.sortBy = 'distance',
  });

  int get activeFilterCount {
    int count = 0;
    if (minBudget > 0 || maxBudget < 100000) count++;
    if (propertyTypes.isNotEmpty) count++;
    if (occupancy.isNotEmpty) count++;
    if (bathrooms.isNotEmpty) count++;
    if (amenities.isNotEmpty) count++;
    if (furnishing.isNotEmpty) count++;
    if (tenants.isNotEmpty) count++;
    if (sortBy != 'distance') count++; // count sort as a filter change for simplicity
    return count;
  }

  FilterState copyWith({
    double? minBudget,
    double? maxBudget,
    List<String>? propertyTypes,
    List<String>? occupancy,
    List<String>? bathrooms,
    List<String>? amenities,
    List<String>? furnishing,
    List<String>? tenants,
    String? sortBy,
  }) {
    return FilterState(
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      occupancy: occupancy ?? this.occupancy,
      bathrooms: bathrooms ?? this.bathrooms,
      amenities: amenities ?? this.amenities,
      furnishing: furnishing ?? this.furnishing,
      tenants: tenants ?? this.tenants,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final FilterState initialState;
  final ValueChanged<FilterState> onApply;

  const FilterBottomSheet({
    Key? key,
    required this.initialState,
    required this.onApply,
  }) : super(key: key);

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterState _state;

  @override
  void _initState() {
    _state = widget.initialState;
  }
  
  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _reset() {
    setState(() {
      _state = const FilterState();
    });
  }

  void _apply() {
    widget.onApply(_state);
    Navigator.pop(context);
  }

  void _toggleList(List<String> list, String value, void Function(List<String>) update) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                GestureDetector(
                  onTap: _reset,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorRed, // Red color as requested
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.errorRed, // ensure underline is also red
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _buildSectionHeader('Sort By'),
                _buildChoiceChips(
                  ['Distance', 'Price: Low to High', 'Price: High to Low'],
                  _state.sortBy == 'distance' ? 'Distance' : (_state.sortBy == 'price_asc' ? 'Price: Low to High' : 'Price: High to Low'),
                  (val) {
                    setState(() {
                      if (val == 'Distance') _state = _state.copyWith(sortBy: 'distance');
                      if (val == 'Price: Low to High') _state = _state.copyWith(sortBy: 'price_asc');
                      if (val == 'Price: High to Low') _state = _state.copyWith(sortBy: 'price_desc');
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Budget Range (₹)'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '₹${_state.minBudget.toInt()} - ${_state.maxBudget >= 100000 ? '₹1L+' : '₹${_state.maxBudget.toInt()}'}',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryYellow,
                        ),
                      ),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(_state.minBudget, _state.maxBudget),
                  min: 0,
                  max: 100000,
                  divisions: 20,
                  activeColor: AppTheme.primaryYellow,
                  inactiveColor: isDark ? Colors.white24 : Colors.grey.shade300,
                  labels: RangeLabels(
                    '₹${_state.minBudget.toInt()}',
                    _state.maxBudget >= 100000 ? '₹1L+' : '₹${_state.maxBudget.toInt()}',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _state = _state.copyWith(minBudget: values.start, maxBudget: values.end);
                    });
                  },
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Property Type'),
                _buildMultiChoiceChips(
                  ['PG', 'Rental', 'Buy', 'Sale'],
                  _state.propertyTypes,
                  (val) => _toggleList(_state.propertyTypes, val, (nl) => _state = _state.copyWith(propertyTypes: nl)),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Occupancy'),
                _buildMultiChoiceChips(
                  ['Single', 'Double', 'Triple', 'Any'],
                  _state.occupancy,
                  (val) => _toggleList(_state.occupancy, val, (nl) => _state = _state.copyWith(occupancy: nl)),
                ),
                const SizedBox(height: 24),
                
                _buildSectionHeader('Furnishing'),
                _buildMultiChoiceChips(
                  ['Fully Furnished', 'Semi Furnished', 'Unfurnished'],
                  _state.furnishing,
                  (val) => _toggleList(_state.furnishing, val, (nl) => _state = _state.copyWith(furnishing: nl)),
                ),
              ],
            ),
          ),
        ),
          
          // Bottom Bar
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black, // Dark text on yellow background
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

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
    final selectedText = Colors.black;
    final selectedBorder = AppTheme.primaryYellow;
    
    final unselectedBg = isDark ? Colors.white10 : Colors.white;
    final unselectedText = isDark ? Colors.grey.shade300 : Colors.black87;
    final unselectedBorder = isDark ? Colors.white24 : Colors.grey.shade300;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorder : unselectedBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}
