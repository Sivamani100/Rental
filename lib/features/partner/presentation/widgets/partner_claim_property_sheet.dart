import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';

class PartnerClaimPropertySheet extends StatefulWidget {
  const PartnerClaimPropertySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PartnerClaimPropertySheet(),
    );
  }

  @override
  State<PartnerClaimPropertySheet> createState() => _PartnerClaimPropertySheetState();
}

class _PartnerClaimPropertySheetState extends State<PartnerClaimPropertySheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<PropertyModel> _allProperties = [];
  List<PropertyModel> _filteredProperties = [];
  PropertyModel? _selectedProperty;

  String _selectedRole = 'Direct Property Owner';
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('properties')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      final list = (res as List)
          .map((row) => PropertyModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      setState(() {
        _allProperties = list;
        _filteredProperties = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching platform properties for handover: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _filteredProperties = _allProperties);
      return;
    }
    setState(() {
      _filteredProperties = _allProperties.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.locationStr.toLowerCase().contains(q) ||
            p.type.toLowerCase().contains(q) ||
            p.price.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _submitRequest() async {
    if (_selectedProperty == null) {
      AppSnackbar.show(context, 'Please select a property first');
      return;
    }

    final note = _noteController.text.trim();
    if (note.isEmpty) {
      AppSnackbar.show(context, 'Please enter a brief note for the admin');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final success = await PartnerService.instance.submitHandoverRequest(
      property: _selectedProperty!,
      role: _selectedRole,
      note: note,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      AppSnackbar.show(
        context,
        'Handover request sent to admin! Admin will review & assign ownership.',
      );
    } else {
      AppSnackbar.show(context, 'Failed to send request. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF14161C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262A34) : const Color(0xFFECEEF2);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final inputBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFF3F4F6);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Iconsax.shield_tick5, size: 18, color: Color(0xFF007AFF)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ask Admin / Handover',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Claim existing platform listings without re-uploading',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subtextColor, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),

          Expanded(
            child: _selectedProperty == null
                ? _buildPropertySelector(isDark, borderColor, textColor, subtextColor, inputBg)
                : _buildRequestForm(isDark, borderColor, textColor, subtextColor, inputBg),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertySelector(
    bool isDark,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color inputBg,
  ) {
    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 14,
                color: textColor,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Iconsax.search_normal_1, size: 18, color: subtextColor),
                hintText: 'Search title, location, or property type...',
                hintStyle: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 13,
                  color: subtextColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // List of platform properties
        Expanded(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _filteredProperties.isEmpty
                  ? Center(
                      child: Text(
                        'No properties found matching search.',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _filteredProperties.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = _filteredProperties[index];
                        final thumb = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;

                        return BouncingButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedProperty = p);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B1E26) : const Color(0xFFFAFAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 62,
                                    height: 62,
                                    color: Colors.grey.shade300,
                                    child: thumb != null
                                        ? CachedNetworkImage(
                                            imageUrl: thumb,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Icon(Iconsax.gallery, size: 24, color: Colors.grey),
                                          )
                                        : const Icon(Iconsax.gallery, size: 24, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'DMSans',
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        p.locationStr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'ProximaNova',
                                          fontSize: 12,
                                          color: subtextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            p.price,
                                            style: TextStyle(
                                              fontFamily: 'ProximaNova',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.swiggyOrange,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p.type,
                                              style: const TextStyle(
                                                fontFamily: 'ProximaNova',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF007AFF),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Iconsax.arrow_right_3, size: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRequestForm(
    bool isDark,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color inputBg,
  ) {
    final p = _selectedProperty!;
    final thumb = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Property Card Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryYellow.withValues(alpha: isDark ? 0.12 : 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryYellow.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 58,
                    height: 58,
                    color: Colors.grey.shade300,
                    child: thumb != null
                        ? CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Iconsax.gallery, size: 24, color: Colors.grey),
                          )
                        : const Icon(Iconsax.gallery, size: 24, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        p.locationStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'ProximaNova', fontSize: 11.5, color: subtextColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.price,
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.swiggyOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedProperty = null),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isDark ? AppTheme.primaryYellow : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ownership Relationship
          Text(
            'WHAT IS YOUR RELATIONSHIP TO THIS PROPERTY?',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildRoleChip(
                  label: 'Direct Owner',
                  subtitle: 'I legally own this property',
                  value: 'Direct Property Owner',
                  icon: Iconsax.user_tag,
                  isDark: isDark,
                  borderColor: borderColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRoleChip(
                  label: 'Dealer / Broker',
                  subtitle: 'I represent this listing',
                  value: 'Dealer / Property Manager',
                  icon: Iconsax.briefcase,
                  isDark: isDark,
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Verification Note
          Text(
            'NOTE TO ADMIN / VERIFICATION DETAILS',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(fontFamily: 'ProximaNova', fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: 'e.g. I am the direct landlord of this property. Please handover ownership to my partner account so I can maintain live pricing and availability.',
                hintStyle: TextStyle(fontFamily: 'ProximaNova', fontSize: 12.5, color: subtextColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Send Request Button
          BouncingButton(
            onTap: _isSubmitting ? null : _submitRequest,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(color: Colors.black)
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.direct_send5, size: 18, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            'Send Handover Claim to Admin',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRoleChip({
    required String label,
    required String subtitle,
    required String value,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
  }) {
    final isSelected = _selectedRole == value;
    return BouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRole = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryYellow.withValues(alpha: isDark ? 0.2 : 0.15)
              : (isDark ? const Color(0xFF1E222B) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryYellow : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? (isDark ? AppTheme.primaryYellow : Colors.black87) : Colors.grey,
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Iconsax.tick_circle5, size: 16, color: Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
