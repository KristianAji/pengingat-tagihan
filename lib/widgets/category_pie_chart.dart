import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Data satu irisan diagram lingkaran.
class PieSlice {
  final String label;
  final double value;
  final Color color;
  const PieSlice(this.label, this.value, this.color);
}

/// Diagram lingkaran (donut) sederhana + legenda, digambar manual.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.slices});

  final List<PieSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Belum ada pengeluaran bulan ini',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(painter: _DonutPainter(slices, total)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices.map((s) {
              final pct = (s.value / total * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total);

  final List<PieSlice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const stroke = 26.0;
    final inner = rect.deflate(stroke / 2);
    double start = -math.pi / 2;

    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(inner, start, sweep - 0.02, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.total != total;
}
