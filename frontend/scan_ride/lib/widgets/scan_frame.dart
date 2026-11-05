import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// กรอบสี่เหลี่ยมเส้นประสีทอง สำหรับวางภาพจากกล้องสแกน QR
class ScanFrame extends StatelessWidget {
  final Widget child;
  final double size;

  const ScanFrame({super.key, required this.child, this.size = 260});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        foregroundPainter:
            _DashedBorderPainter(color: AppColors.gold, radius: 22),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// วาดเส้นขอบแบบประ (Flutter ไม่มีเส้นประสำเร็จรูป จึงวาดเอง)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double stroke;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    this.dash = 10,
    this.gap = 7,
    this.stroke = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(stroke / 2);
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
