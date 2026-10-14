import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/property_posting/presentation/pages/posting_screen.dart';

class PartnerPropertyEditSheet extends StatefulWidget {
  final PropertyModel property;

  const PartnerPropertyEditSheet({
    super.key,
    required this.property,
  });

  static Future<void> show(BuildContext context, PropertyModel property) {
    return Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PostingScreen(propertyToEdit: property),
      ),
    );
  }

  @override
  State<PartnerPropertyEditSheet> createState() => _PartnerPropertyEditSheetState();
}

class _PartnerPropertyEditSheetState extends State<PartnerPropertyEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _depositController;
  late TextEditingController _phoneController;
  late TextEditingController _descController;
  late bool _isAvailable;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.property.title);
    _priceController = TextEditingController(text: widget.property.price);
    _depositController = TextEditingController(text: widget.property.securityDeposit ?? '');
    _phoneController = TextEditingController(text: widget.property.ownerPhone);
    _descController = TextEditingController(text: widget.property.description ?? '');
    _isAvailable = widget.property.isAvailable;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _phoneController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final price = _priceController.text.trim();
    final phone = _phoneController.text.trim();

    if (title.isEmpty) {
      AppSnackbar.show(context, 'Please enter a property title');
      return;
    }
    if (price.isEmpty) {
      AppSnackbar.show(context, 'Please enter rent price');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final updates = {
      'title': title,
      'price': price,
      'security_deposit': _depositController.text.trim(),
      'owner_phone': phone,
      'description': _descController.text.trim(),
      'is_available': _isAvailable,
    };

    final success = await PartnerService.instance.updatePropertyDetails(
      propertyId: widget.property.id!,
      updates: updates,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      AppSnackbar.show(context, 'Property updated successfully!');
    } else {
      AppSnackbar.show(context, 'Could not save changes. Please try again.');
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
          // Drag handle
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.swiggyOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Iconsax.edit_2, size: 18, color: AppTheme.swiggyOrange),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Property Details',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
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
          const SizedBox(height: 10),
          Divider(height: 1, color: borderColor),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Editor Banner
                  BouncingButton(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => PostingScreen(propertyToEdit: widget.property),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryYellow.withValues(alpha: isDark ? 0.25 : 0.2),
                            AppTheme.primaryYellow.withValues(alpha: isDark ? 0.1 : 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryYellow.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryYellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Iconsax.gallery_edit, size: 18, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete Property Editor',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Edit Photos, BHK, Sharing, Food, Amenities & Map Location',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 11,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Iconsax.arrow_right_3, size: 16, color: textColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Availability Switch Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isAvailable
                          ? AppTheme.swiggyGreen.withValues(alpha: isDark ? 0.18 : 0.1)
                          : AppTheme.swiggyRed.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isAvailable
                            ? AppTheme.swiggyGreen.withValues(alpha: 0.4)
                            : AppTheme.swiggyRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isAvailable ? Iconsax.tick_circle5 : Iconsax.close_circle5,
                              color: _isAvailable ? AppTheme.swiggyGreen : AppTheme.swiggyRed,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isAvailable ? 'Property is AVAILABLE' : 'Property is OCCUPIED / SOLD',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _isAvailable ? AppTheme.swiggyGreen : AppTheme.swiggyRed,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _isAvailable ? 'Visible to prospective tenants' : 'Showing in greyscale with stamp',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 11.5,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          value: _isAvailable,
                          activeTrackColor: AppTheme.swiggyGreen,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _isAvailable = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  _label('PROPERTY TITLE', subtextColor),
                  _field(_titleController, 'e.g. Spacious 2BHK in Banjara Hills', inputBg, borderColor, textColor, subtextColor),
                  const SizedBox(height: 16),

                  // Price & Deposit in Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('RENT PRICE', subtextColor),
                            _field(_priceController, 'e.g. ₹18,000/mo', inputBg, borderColor, textColor, subtextColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('SECURITY DEPOSIT', subtextColor),
                            _field(_depositController, 'e.g. ₹36,000', inputBg, borderColor, textColor, subtextColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Phone
                  _label('OWNER CONTACT NUMBER', subtextColor),
                  _field(
                    _phoneController,
                    '10-digit mobile number',
                    inputBg,
                    borderColor,
                    textColor,
                    subtextColor,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _label('DESCRIPTION', subtextColor),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 4,
                      style: TextStyle(fontFamily: 'ProximaNova', fontSize: 13.5, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Describe key highlights, furnishing details, rules, etc...',
                        hintStyle: TextStyle(fontFamily: 'ProximaNova', fontSize: 13, color: subtextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  BouncingButton(
                    onTap: _isSaving ? null : _save,
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
                        child: _isSaving
                            ? const CupertinoActivityIndicator(color: Colors.black)
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    Color bg,
    Color borderColor,
    Color text,
    Color subtext, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 13,
            color: subtext,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}
