import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/widgets/partner_property_card.dart';
import 'package:rental/features/partner/presentation/widgets/partner_claim_card.dart';
import 'package:rental/features/partner/presentation/widgets/partner_claim_property_sheet.dart';
import 'package:rental/features/partner/presentation/widgets/partner_create_promotion_sheet.dart';
import 'package:rental/features/property_posting/presentation/pages/posting_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';

class PartnerPropertiesTab extends StatefulWidget {
  final VoidCallback onRefresh;
  final ValueChanged<PropertyModel> onToggleAvailability;
  final int initialSegment; // 0: Properties, 1: Claims

  const PartnerPropertiesTab({
    super.key,
    required this.onRefresh,
    required this.onToggleAvailability,
    this.initialSegment = 0,
  });

  @override
  State<PartnerPropertiesTab> createState() => _PartnerPropertiesTabState();
}

class _PartnerPropertiesTabState extends State<PartnerPropertiesTab> {
  late int _selectedSegment;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'available', 'occupied', 'pending'

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.initialSegment;
  }

  void _openUploadProperty() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const PostingScreen()),
    ).then((_) => widget.onRefresh());
  }

  void _openClaimSheet() {
    HapticFeedback.mediumImpact();
    PartnerClaimPropertySheet.show(context).then((_) => widget.onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E222B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);

    final allProperties = PartnerService.instance.myProperties;
    final allRequests = PartnerService.instance.myRequests;

    final availableCount = allProperties.where((p) => p.isAvailable).length;
    final occupiedCount = allProperties.where((p) => !p.isAvailable).length;
    final pendingCount = allProperties.where((p) => p.status != 'approved').length;

    // Filter properties based on search query and status filter
    final filteredProperties = allProperties.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.locationStr.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.type.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesQuery) return false;

      switch (_selectedStatusFilter) {
        case 'available':
          return p.isAvailable;
        case 'occupied':
          return !p.isAvailable;
        case 'pending':
          return p.status != 'approved';
        default:
          return true;
      }
    }).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Bar: Segment Switcher + Compact Action Buttons ─
          Row(
            children: [
              // Segmented Pill (Listings vs Claims)
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15181E) : const Color(0xFFE9ECF0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Listings Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSegment = 0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedSegment == 0 ? cardColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _selectedSegment == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Listings',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: _selectedSegment == 0 ? textColor : subtextColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _selectedSegment == 0
                                        ? AppTheme.primaryYellow.withValues(alpha: 0.25)
                                        : (isDark ? Colors.white10 : Colors.black12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${allProperties.length}',
                                    style: TextStyle(
                                      fontFamily: 'ProximaNova',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedSegment == 0
                                          ? (isDark ? AppTheme.primaryYellow : Colors.black87)
                                          : subtextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Claims Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSegment = 1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedSegment == 1 ? cardColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _selectedSegment == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Claims',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: _selectedSegment == 1 ? textColor : subtextColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _selectedSegment == 1
                                        ? const Color(0xFF007AFF).withValues(alpha: 0.18)
                                        : (isDark ? Colors.white10 : Colors.black12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${allRequests.length}',
                                    style: TextStyle(
                                      fontFamily: 'ProximaNova',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedSegment == 1 ? const Color(0xFF007AFF) : subtextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Compact + Upload Button
              BouncingButton(
                onTap: _openUploadProperty,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.add, size: 16, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'Upload',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Compact Ask Admin Button
              BouncingButton(
                onTap: _openClaimSheet,
                child: Container(
                  height: 40,
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Icon(
                    CupertinoIcons.shield_fill,
                    size: 18,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 2. Segment Content ───────────────────────────────────
          if (_selectedSegment == 0) ...[
            // Search Input Field
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Iconsax.search_normal, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search properties by title, locality or type...',
                        hintStyle: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 12.5,
                          color: subtextColor,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchQuery = ''),
                      child: Icon(Icons.close, size: 16, color: subtextColor),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Horizontal Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', allProperties.length, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Available',
                    'available',
                    availableCount,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Occupied',
                    'occupied',
                    occupiedCount,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Under Review',
                    'pending',
                    pendingCount,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Property Cards List
            if (filteredProperties.isEmpty)
              _buildEmptyProperties(cardColor, borderColor, textColor, subtextColor, isDark)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProperties.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = filteredProperties[index];
                  return PartnerPropertyCard(
                    property: p,
                    onToggleAvailability: widget.onToggleAvailability,
                    onEdit: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => PostingScreen(propertyToEdit: p)),
                      ).then((_) => widget.onRefresh());
                    },
                    onView: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
                      );
                    },
                    onPromote: () {
                      PartnerCreatePromotionSheet.show(
                        context,
                        initialProperty: p,
                      ).then((_) => widget.onRefresh());
                    },
                  );
                },
              ),
          ] else ...[
            // Claims / Handover List
            if (allRequests.isEmpty)
              _buildEmptyClaims(cardColor, borderColor, textColor, subtextColor, isDark)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allRequests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return PartnerClaimCard(request: allRequests[index]);
                },
              ),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, bool isDark) {
    final isSelected = _selectedStatusFilter == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStatusFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryYellow
              : (isDark ? const Color(0xFF1E222B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryYellow
                : (isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : (isDark ? const Color(0xFFB0B7C3) : const Color(0xFF4B5563)),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProperties(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.buildings, size: 26, color: subtextColor),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                ? 'No matching properties'
                : 'No properties added yet',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                ? 'Try adjusting your search query or status filter to see results.'
                : 'Upload your first rental, flat, or PG listing to start managing tenants and tracking analytics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 12.5,
              color: subtextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          BouncingButton(
            onTap: _openUploadProperty,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.add, size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'Upload Property',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
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

  Widget _buildEmptyClaims(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.shield_fill, size: 26, color: Color(0xFF007AFF)),
          ),
          const SizedBox(height: 14),
          Text(
            'No Claim Requests',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Did another agent or team post your property? Submit a claim request with property details to get landlord controls.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 12.5,
              color: subtextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          BouncingButton(
            onTap: _openClaimSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.shield_fill, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Claim Property via Admin',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
