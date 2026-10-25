import 'package:flutter/material.dart';

/// Sparkline of the lag readings retained for one group or partition.
///
/// Fewer than two readings render nothing: a single point carries no trend.
class LagTrend extends StatelessWidget {
  final List<int> readings;
  final String tooltip;

  static const double width = 48;
  static const double height = 16;

  const LagTrend({super.key, required this.readings, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    if (readings.length < 2) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final rising = readings.last > readings.first;

    return Tooltip(
      message: tooltip,
      child: CustomPaint(
        key: const Key('lag_trend'),
        size: const Size(width, height),
        painter: _TrendPainter(
          readings: readings,
          color: rising ? scheme.error : scheme.primary,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<int> readings;
  final Color color;

  _TrendPainter({required this.readings, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final highest = readings.reduce((a, b) => a > b ? a : b);
    final lowest = readings.reduce((a, b) => a < b ? a : b);
    final span = (highest - lowest).toDouble();
    final stepX = size.width / (readings.length - 1);

    double yOf(int value) => span == 0
        ? size.height / 2
        : size.height - (value - lowest) / span * size.height;

    final path = Path()..moveTo(0, yOf(readings.first));
    for (var i = 1; i < readings.length; i++) {
      path.lineTo(i * stepX, yOf(readings[i]));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.readings != readings || old.color != color;
}
