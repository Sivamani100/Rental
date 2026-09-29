import 'dart:math' as math;
import 'package:flutter/material.dart';

class RentalAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RentalAppIcon({
    super.key,
    this.size = 14,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
        angle: 65 * math.pi / 180, // 65 degrees
        child: CustomPaint(
          painter: _RentalAppIconPainter(color: color),
        ),
      ),
    );
  }
}

class _RentalAppIconPainter extends CustomPainter {
  final Color color;

  _RentalAppIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ViewBox is 16x16
    final scale = size.width / 16.0;
    canvas.save();
    canvas.scale(scale, scale);

    final path = Path();
    // M4.002 2.998
    path.moveTo(4.002, 2.998);
    // a1 1 0 0 1 1.6-.8
    path.arcToPoint(
      const Offset(5.602, 2.198),
      radius: const Radius.circular(1.0),
      clockwise: true,
    );
    // L13.6 8.2
    path.lineTo(13.6, 8.2);
    // c.768.576.36 1.8-.6 1.8
    path.cubicTo(
      13.6 + 0.768,
      8.2 + 0.576,
      13.6 + 0.36,
      8.2 + 1.8,
      13.6 - 0.6,
      8.2 + 1.8,
    );
    // H9.053
    path.lineTo(9.053, 10.0);
    // a1 1 0 0 0-.793.39
    path.arcToPoint(
      const Offset(8.26, 10.39),
      radius: const Radius.circular(1.0),
      clockwise: false,
    );
    // l-2.466 3.215
    path.lineTo(5.794, 13.605);
    // c-.581.758-1.793.347-1.793-.609
    path.cubicTo(
      5.794 - 0.581,
      13.605 + 0.758,
      5.794 - 1.793,
      13.605 + 0.347,
      5.794 - 1.793,
      13.605 - 0.609,
    );
    // z
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RentalAppIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
