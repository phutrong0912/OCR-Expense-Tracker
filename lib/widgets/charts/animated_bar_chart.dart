import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../database/db_helper.dart';

/// Weekly Spending Bar Chart implemented strictly via CustomPainter (zero 3rd party libs)
class AnimatedBarChart extends StatefulWidget {
  final List<DailySpending> data;
  final double height;
  final Duration animationDuration;

  const AnimatedBarChart({
    super.key,
    required this.data,
    this.height = 220,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPosition, Size canvasSize) {
    if (widget.data.isEmpty) return;

    const leftPadding = 48.0;
    const rightPadding = 16.0;
    final chartWidth = canvasSize.width - leftPadding - rightPadding;
    final slotWidth = chartWidth / widget.data.length;

    if (localPosition.dx >= leftPadding && localPosition.dx <= canvasSize.width - rightPadding) {
      final index = ((localPosition.dx - leftPadding) / slotWidth).floor();
      if (index >= 0 && index < widget.data.length) {
        setState(() {
          _touchedIndex = index;
        });
      }
    } else {
      if (_touchedIndex != null) {
        setState(() {
          _touchedIndex = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No weekly spending data recorded', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onTapDown: (details) => _handleTouch(details.localPosition, Size(width, widget.height)),
          onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition, Size(width, widget.height)),
          onTapUp: (_) {
            // Keep tooltip for a moment or allow toggle
          },
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(width, widget.height),
                painter: _BarChartPainter(
                  data: widget.data,
                  progress: _animation.value,
                  touchedIndex: _touchedIndex,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Pure CustomPainter drawing axes, grid lines, bars, average dashed line, and tooltips
class _BarChartPainter extends CustomPainter {
  final List<DailySpending> data;
  final double progress;
  final int? touchedIndex;

  _BarChartPainter({
    required this.data,
    required this.progress,
    required this.touchedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 48.0;
    const bottomPadding = 32.0;
    const topPadding = 28.0;
    const rightPadding = 16.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // 1. Calculate dynamic max scale
    double maxSpending = 0.0;
    double totalSpending = 0.0;
    for (final day in data) {
      if (day.totalAmount > maxSpending) maxSpending = day.totalAmount;
      totalSpending += day.totalAmount;
    }
    final avgSpending = data.isNotEmpty ? (totalSpending / data.length) : 0.0;

    // Round maxSpending up to a visually pleasing interval
    double maxScale = _calculateNiceMax(maxSpending);
    if (maxScale <= 0) maxScale = 100000;

    // 2. Draw Horizontal Grid Lines & Y-Axis Labels
    const gridDivisions = 4;
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i <= gridDivisions; i++) {
      final ratio = i / gridDivisions;
      final y = topPadding + chartHeight * (1.0 - ratio);
      final value = maxScale * ratio;

      // Grid line
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y Label
      final labelText = _formatCompactNumber(value);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPadding - 6);

      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // 3. Draw Dashed Average Reference Line
    if (avgSpending > 0 && avgSpending <= maxScale) {
      final avgY = topPadding + chartHeight * (1.0 - (avgSpending / maxScale));
      _drawDashedLine(
        canvas,
        Offset(leftPadding, avgY),
        Offset(size.width - rightPadding, avgY),
        Colors.amber.shade700,
      );

      // Average badge label
      final avgLabel = 'Avg: ${_formatCompactNumber(avgSpending)}';
      final avgPainter = TextPainter(
        text: TextSpan(
          text: avgLabel,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      avgPainter.paint(
        canvas,
        Offset(size.width - rightPadding - avgPainter.width - 2, avgY - avgPainter.height - 2),
      );
    }

    // 4. Draw Bars & X-Axis Day Labels
    final slotWidth = chartWidth / data.length;
    final barWidth = slotWidth * 0.52;

    Offset? tooltipTarget;
    String? tooltipText;

    for (int i = 0; i < data.length; i++) {
      final day = data[i];
      final isTouched = touchedIndex == i;
      final barCenterX = leftPadding + (i + 0.5) * slotWidth;
      final targetBarHeight = (day.totalAmount / maxScale) * chartHeight;
      final currentBarHeight = targetBarHeight * progress;

      final barRect = Rect.fromCenter(
        center: Offset(barCenterX, topPadding + chartHeight - currentBarHeight / 2),
        width: barWidth,
        height: math.max(2.0, currentBarHeight),
      );

      // Rounded top bar shape
      final rrect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      // Gradient Fill
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: isTouched
              ? [const Color(0xFF6366F1), const Color(0xFF818CF8)]
              : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
        ).createShader(barRect);

      canvas.drawRRect(rrect, barPaint);

      // Highlight border if touched
      if (isTouched) {
        final borderPaint = Paint()
          ..color = const Color(0xFF1E40AF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(rrect, borderPaint);

        tooltipTarget = Offset(barCenterX, topPadding + chartHeight - currentBarHeight);
        tooltipText = '${day.dayName}: ${_formatExactAmount(day.totalAmount)}';
      }

      // X Label (Day name)
      final dayPainter = TextPainter(
        text: TextSpan(
          text: day.dayName,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
            color: isTouched ? const Color(0xFF1E40AF) : Colors.grey.shade700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      dayPainter.paint(
        canvas,
        Offset(barCenterX - dayPainter.width / 2, size.height - bottomPadding + 6),
      );
    }

    // 5. Draw Interactive Floating Tooltip Pill
    if (tooltipTarget != null && tooltipText != null) {
      _drawTooltip(canvas, tooltipTarget, tooltipText);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = p1.dx;

    while (startX < p2.dx) {
      final endX = math.min(startX + dashWidth, p2.dx);
      canvas.drawLine(Offset(startX, p1.dy), Offset(endX, p1.dy), paint);
      startX += dashWidth + dashSpace;
    }
  }

  void _drawTooltip(Canvas canvas, Offset anchor, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const hPadding = 8.0;
    const vPadding = 4.0;
    final pillWidth = textPainter.width + hPadding * 2;
    final pillHeight = textPainter.height + vPadding * 2;

    final pillRect = Rect.fromCenter(
      center: Offset(anchor.dx, math.max(pillHeight / 2 + 2, anchor.dy - pillHeight / 2 - 8)),
      width: pillWidth,
      height: pillHeight,
    );

    final rrect = RRect.fromRectAndRadius(pillRect, const Radius.circular(6));

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    final bgPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(rrect, bgPaint);

    textPainter.paint(
      canvas,
      Offset(pillRect.left + hPadding, pillRect.top + vPadding),
    );
  }

  double _calculateNiceMax(double value) {
    if (value <= 0) return 100000;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final fraction = value / magnitude;

    double niceFraction;
    if (fraction <= 1.0) {
      niceFraction = 1.0;
    } else if (fraction <= 2.0) {
      niceFraction = 2.0;
    } else if (fraction <= 5.0) {
      niceFraction = 5.0;
    } else {
      niceFraction = 10.0;
    }

    return niceFraction * magnitude;
  }

  String _formatCompactNumber(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).round()}k';
    } else {
      return amount.round().toString();
    }
  }

  String _formatExactAmount(double amount) {
    if (amount >= 1000) {
      final str = amount.round().toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
        buffer.write(str[i]);
      }
      return '${buffer.toString()} ₫';
    } else {
      return '\$${amount.toStringAsFixed(2)}';
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.touchedIndex != touchedIndex ||
        oldDelegate.data != data;
  }
}
