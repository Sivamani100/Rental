import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';

class PartnerCreatePromotionSheet extends StatefulWidget {
  final PropertyModel? initialProperty;
  final String initialType; // 'in_app' or 'external'

  const PartnerCreatePromotionSheet({
    super.key,
    this.initialProperty,
    this.initialType = 'in_app',
  });

  static Future<bool?> show(
    BuildContext context, {
    PropertyModel? initialProperty,
    String initialType = 'in_app',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartnerCreatePromotionSheet(
        initialProperty: initialProperty,
        initialType: initialType,
      ),
    );
  }

  @override
  State<PartnerCreatePromotionSheet> createState() =>
      _PartnerCreatePromotionSheetState();
}

class _PartnerCreatePromotionSheetState
    extends State<PartnerCreatePromotionSheet> {
  late PropertyModel? _selectedProperty;
  late String _promotionType; // 'in_app' or 'external'
  int _selectedPlanIndex = 1; // Default to Pro plan (index 1)
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _inAppPlans = [
    {
      'name': 'Starter Spotlight',
      'duration': 3,
      'price': '₹299',
      'estViews': '500 - 1,000 views',
      'tag': 'BASIC BOOST',
      'channels': ['In-App Search', 'Locality Feed'],
      'features': [
        'Top placement in locality search',
        'Golden Featured badge',
        'Direct inquiry button',
      ],
    },
    {
      'name': 'Pro Booster',
      'duration': 7,
      'price': '₹599',
      'estViews': '2,500 - 4,000 views',
      'tag': 'MOST POPULAR',
      'isPopular': true,
      'channels': ['In-App Search', 'Home Feed', 'Locality Push'],
      'features': [
        'Top pinned search placement',
        'Locality push notification blast',
        'High-converting Yellow frame',
        'Dedicated WhatsApp inquiry leads',
      ],
    },
    {
      'name': 'Ultimate Blitz',
      'duration': 15,
      'price': '₹1,199',
      'estViews': '8,000+ views',
      'tag': 'MAXIMUM REACH',
      'channels': ['Home Banner', 'Search #1', 'Push Blast', 'Direct SMS'],
      'features': [
        'Hero carousel banner on Home screen',
        'Guaranteed top 3 search rank',
        'City-wide tenant alert notification',
        'Zero commission tenant assurance',
      ],
    },
  ];

  final List<Map<String, dynamic>> _externalPlans = [
    {
      'name': 'Meta Social Launchpad',
      'duration': 7,
      'price': '₹799',
      'estViews': '4,500 - 7,000 reach',
      'tag': 'INSTAGRAM & FB',
      'channels': ['Instagram Feed', 'Instagram Stories', 'Facebook Feed'],
      'features': [
        'Sponsored ads targeted to 5km radius',
        'Direct link to your rental listing',
        'Targeted to verified home seekers',
      ],
    },
    {
      'name': 'Hyperlocal Google Ads',
      'duration': 10,
      'price': '₹1,299',
      'estViews': 'Top Search Appearances',
      'tag': 'GOOGLE HIGH INTENT',
      'isPopular': true,
      'channels': ['Google Search', 'Google Maps', 'Partner Network'],
      'features': [
        'Ranks on Google: "House for rent in [Locality]"',
        'Calls routed directly to your number',
        'High-intent tenants ready to shift',
      ],
    },
    {
      'name': '360° Omnichannel Pro',
      'duration': 15,
      'price': '₹2,499',
      'estViews': '15,000+ combined reach',
      'tag': 'FULL DIGITAL SUITE',
      'channels': ['In-App Spotlight', 'Instagram Ads', 'Google Ads', 'WhatsApp Kit'],
      'features': [
        'Both In-App Spotlight + Social & Google ads',
        'Custom social video flyer crafted by designers',
        'Dedicated landlord marketing manager',
        'Lead guarantee within 10 days',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _promotionType = widget.initialType;
    final properties = PartnerService.instance.myProperties;
    if (widget.initialProperty != null) {
      _selectedProperty = widget.initialProperty;
    } else if (properties.isNotEmpty) {
      _selectedProperty = properties.first;
    } else {
      _selectedProperty = null;
    }
  }

  void _onLaunchPromotion() async {
    if (_selectedProperty == null) {
      AppSnackbar.show(context, 'Please select a property to promote.');
      return;
    }

    final plans = _promotionType == 'in_app' ? _inAppPlans : _externalPlans;
    final selectedPlan = plans[_selectedPlanIndex];

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await PartnerService.instance.createPromotion(
        property: _selectedProperty!,
        type: _promotionType,
        packageName: selectedPlan['name'] as String,
        durationDays: selectedPlan['duration'] as int,
        price: selectedPlan['price'] as String,
        channels: List<String>.from(selectedPlan['channels'] as List),
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        AppSnackbar.show(
          context,
          '🚀 Promotion requested! Admin is reviewing and assigning priority rank (1, 2, 3...) for 5km feed boost.',
        );
      } else {
        AppSnackbar.show(context, 'Failed to launch promotion. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF14171E) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1B1E26) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF2B2F3B) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final allProperties = PartnerService.instance.myProperties;
    final currentPlans = _promotionType == 'in_app' ? _inAppPlans : _externalPlans;
    final activePlan = currentPlans[_selectedPlanIndex];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.flash5, size: 18, color: Colors.black),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Promote Property',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Boost reach & get verified tenant inquiries',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: subtextColor, size: 22),
                ),
              ],
            ),
          ),
          Divider(color: borderColor, height: 16),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // 1. Property Selector
                Text(
                  '1. SELECT PROPERTY TO PROMOTE',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 8),

                if (allProperties.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'No properties linked to your account yet.\nPlease upload or claim a property first.',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 13,
                          color: subtextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PropertyModel>(
                        value: _selectedProperty ?? allProperties.first,
                        isExpanded: true,
                        dropdownColor: bgColor,
                        icon: Icon(Iconsax.arrow_down_1, size: 18, color: textColor),
                        items: allProperties.map((p) {
                          final thumb = p.imageUrls.isNotEmpty ? p.imageUrls.first : '';
                          return DropdownMenuItem<PropertyModel>(
                            value: p,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: thumb.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: thumb,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) => Container(
                                            width: 38,
                                            height: 38,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Iconsax.building, size: 18),
                                          ),
                                        )
                                      : Container(
                                          width: 38,
                                          height: 38,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Iconsax.building, size: 18),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        p.title,
                                        style: TextStyle(
                                          fontFamily: 'ProximaNova',
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${p.locationStr} • ${p.price}',
                                        style: TextStyle(
                                          fontFamily: 'ProximaNova',
                                          fontSize: 11,
                                          color: subtextColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newProp) {
                          if (newProp != null) {
                            setState(() => _selectedProperty = newProp);
                          }
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // 2. Promotion Type Switcher
                Text(
                  '2. CHOOSE PROMOTION CHANNEL',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF101217) : const Color(0xFFEDEFF3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      // In-App Promoting
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _promotionType = 'in_app';
                              _selectedPlanIndex = 1;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _promotionType == 'in_app' ? bgColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _promotionType == 'in_app'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.mobile,
                                  size: 16,
                                  color: _promotionType == 'in_app'
                                      ? AppTheme.primaryYellow
                                      : subtextColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'In-App Promoting',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _promotionType == 'in_app' ? textColor : subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // External Promoting
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _promotionType = 'external';
                              _selectedPlanIndex = 1;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _promotionType == 'external' ? bgColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _promotionType == 'external'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.global,
                                  size: 16,
                                  color: _promotionType == 'external'
                                      ? const Color(0xFF007AFF)
                                      : subtextColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'External Promoting',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _promotionType == 'external' ? textColor : subtextColor,
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

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _promotionType == 'in_app'
                        ? AppTheme.primaryYellow.withValues(alpha: isDark ? 0.12 : 0.15)
                        : const Color(0xFF007AFF).withValues(alpha: isDark ? 0.12 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _promotionType == 'in_app'
                          ? AppTheme.primaryYellow.withValues(alpha: 0.3)
                          : const Color(0xFF007AFF).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _promotionType == 'in_app' ? Iconsax.info_circle : Iconsax.share,
                        size: 18,
                        color: _promotionType == 'in_app'
                            ? (isDark ? AppTheme.primaryYellow : const Color(0xFFB45309))
                            : const Color(0xFF007AFF),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _promotionType == 'in_app'
                              ? 'Promote inside Rental Ecosystem app. Pinned at top of search results + sent to tenants searching in this area.'
                              : 'Targeted ads across Instagram, Facebook & Google Search reaching thousands of active house-hunters nearby.',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Select Plan
                Text(
                  '3. SELECT BOOST PLAN',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 10),

                Column(
                  children: currentPlans.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final plan = entry.value;
                    final isSelected = _selectedPlanIndex == idx;
                    final isPopular = plan['isPopular'] == true;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPlanIndex = idx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (_promotionType == 'in_app'
                                  ? AppTheme.primaryYellow.withValues(alpha: isDark ? 0.15 : 0.12)
                                  : const Color(0xFF007AFF).withValues(alpha: isDark ? 0.15 : 0.08))
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (_promotionType == 'in_app'
                                    ? AppTheme.primaryYellow
                                    : const Color(0xFF007AFF))
                                : borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? (_promotionType == 'in_app'
                                                ? AppTheme.primaryYellow
                                                : const Color(0xFF007AFF))
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.transparent
                                              : (isDark ? Colors.white38 : Colors.grey.shade400),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 13, color: Colors.black)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      plan['name'] as String,
                                      style: TextStyle(
                                        fontFamily: 'ProximaNova',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isPopular)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9500),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'POPULAR',
                                      style: TextStyle(
                                        fontFamily: 'ProximaNova',
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Duration: ${plan['duration']} Days • ${plan['estViews']}',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 12,
                                    color: subtextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  plan['price'] as String,
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? (_promotionType == 'in_app'
                                            ? (isDark ? AppTheme.primaryYellow : const Color(0xFFB45309))
                                            : const Color(0xFF007AFF))
                                        : textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Features bullet points
                            ...(plan['features'] as List<String>).map((f) => Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Iconsax.tick_circle5,
                                        size: 13,
                                        color: isSelected ? AppTheme.swiggyGreen : subtextColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          f,
                                          style: TextStyle(
                                            fontFamily: 'ProximaNova',
                                            fontSize: 11.5,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          // Bottom Launch Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL INVESTMENT',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: subtextColor,
                          ),
                        ),
                        Text(
                          activePlan['price'] as String,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: BouncingButton(
                      onTap: _isSubmitting ? () {} : _onLaunchPromotion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _promotionType == 'in_app'
                              ? AppTheme.primaryYellow
                              : const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (_promotionType == 'in_app'
                                      ? AppTheme.primaryYellow
                                      : const Color(0xFF007AFF))
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CupertinoActivityIndicator(
                                    radius: 9,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Iconsax.flash5,
                                      size: 18,
                                      color: _promotionType == 'in_app' ? Colors.black : Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Launch Promotion',
                                      style: TextStyle(
                                        fontFamily: 'ProximaNova',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: _promotionType == 'in_app' ? Colors.black : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
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
