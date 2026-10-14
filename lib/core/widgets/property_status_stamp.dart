import 'package:flutter/material.dart';

/// Authentic distressed stamp tag displayed over property photos
/// when a property is unavailable (OCCUPIED for rentals/PGs, SOLD for buy/sale).
class PropertyStatusStamp extends StatelessWidget {
  final String text; // 'OCCUPIED' or 'SOLD'
  final bool isCompact; // For grid cards
  final bool isLarge;   // For details hero & full-screen viewer
  final double? width;  // Optional explicit width override

  const PropertyStatusStamp({
    super.key,
    required this.text,
    this.isCompact = false,
    this.isLarge = false,
    this.width,
  });

  /// Automatically derives 'OCCUPIED' (default for rental/PG) or 'SOLD' (for Buy/Sale)
  factory PropertyStatusStamp.fromPropertyType({
    Key? key,
    required String propertyType,
    bool isCompact = false,
    bool isLarge = false,
    double? width,
  }) {
    final lower = propertyType.toLowerCase().trim();
    final isBuy = lower == 'buy' || lower == 'sale';
    return PropertyStatusStamp(
      key: key,
      text: isBuy ? 'SOLD' : 'OCCUPIED',
      isCompact: isCompact,
      isLarge: isLarge,
      width: width,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSold = text.toUpperCase().contains('SOLD');
    final String assetPath = isSold
        ? 'assets/images/tag_sold.png'
        : 'assets/images/tag_occupied.png';

    // Tasteful, proportional sizing so the image remains clean, crisp, and never overpowers the photo
    final double targetWidth = width ??
        (isCompact
            ? 78.0
            : (isLarge ? 140.0 : 110.0));

    return IgnorePointer(
      child: Center(
        child: Image.asset(
          assetPath,
          width: targetWidth,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 14,
                vertical: isCompact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE5252A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 10 : 13,
                  letterSpacing: 1.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
