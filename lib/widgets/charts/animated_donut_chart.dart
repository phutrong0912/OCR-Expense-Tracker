import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../database/db_helper.dart';

/// Animated Donut Chart implemented strictly via CustomPainter (zero 3rd party libs)
class AnimatedDonutChart extends StatefulWidget {
  final List<CategorySpending> data;
  final double size;
  final Duration animationDuration;

  const AnimatedDonutChart({
    super.key,
    required this.data,
    this.size = 240,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

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
  void didUpdateWidget(AnimatedDonutChart oldWidget) {
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

  void _handleTap(Offset localPosition, Size canvasSize) {
    if (widget.data.isEmpty) return;

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = math.min(canvasSize.width, canvasSize.height) / 2;
    final innerRadius = outerRadius * 0.58;

    // Check if tap fell inside donut ring
    if (distance >= innerRadius * 0.8 && distance <= outerRadius * 1.15) {
      // Calculate angle in radians [0, 2*pi]
      var angle = math.atan2(dy, dx);
      // Shift so 0 radians starts at top (-pi/2)
      angle += math.pi / 2;
      if (angle < 0) angle += 2 * math.pi;

      double accumulatedAngle = 0.0;
      for (int i = 0; i < widget.data.length; i++) {
        final sweep = (widget.data[i].percentage / 100.0) * 2 * math.pi;
        if (angle >= accumulatedAngle && angle <= accumulatedAngle + sweep) {
          setState(() {
            _selectedIndex = (_selectedIndex == i) ? null : i;
          });
          return;
        }
        accumulatedAngle += sweep;
      }
    } else {
      // Tap outside or inside center hole resets selection
      if (_selectedIndex != null) {
        setState(() {
          _selectedIndex = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.size,
        child: const Center(
          child: Text(
            'No expense data to visualize yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final totalAmount = widget.data.fold<double>(0.0, (s, d) => s + d.totalAmount);
    final selectedItem = (_selectedIndex != null && _selectedIndex! < widget.data.length)
        ? widget.data[_selectedIndex!]
        : null;

    return Column(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: GestureDetector(
            onTapUp: (details) => _handleTap(details.localPosition, Size(widget.size, widget.size)),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _DonutChartPainter(
                    data: widget.data,
                    progress: _animation.value,
                    selectedIndex: _selectedIndex,
                    totalAmount: totalAmount,
                    selectedItem: selectedItem,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Interactive Category Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(widget.data.length, (index) {
            final item = widget.data[index];
            final isSelected = _selectedIndex == index;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedIndex = isSelected ? null : index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Color(item.category.colorHex).withOpacity(0.2)
                      : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Color(item.category.colorHex)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(item.category.colorHex),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.category.name} (${item.percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Color(item.category.colorHex) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Pure CustomPainter responsible for rendering arc sweeps and center text
class _DonutChartPainter extends CustomPainter {
  final List<CategorySpending> data;
  final double progress;
  final int? selectedIndex;
  final double totalAmount;
  final CategorySpending? selectedItem;

  _DonutChartPainter({
    required this.data,
    required this.progress,
    required this.selectedIndex,
    required this.totalAmount,
    this.selectedItem,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 12;
    final strokeWidth = outerRadius * 0.32;
    final arcRadius = outerRadius - strokeWidth / 2;

    double startAngle = -math.pi / 2; // Start from top 12 o'clock

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final isSelected = selectedIndex == i;
      final sweepAngle = (item.percentage / 100.0) * 2 * math.pi * progress;
      final gap = (data.length > 1) ? 0.035 : 0.0;

      final paint = Paint()
        ..color = Color(item.category.colorHex)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      Offset segmentCenter = center;

      // Slice explosion physics: push selected segment outward along bisector
      if (isSelected) {
        final midAngle = startAngle + sweepAngle / 2;
        const explodeDistance = 7.0;
        segmentCenter = Offset(
          center.dx + math.cos(midAngle) * explodeDistance,
          center.dy + math.sin(midAngle) * explodeDistance,
        );

        // Draw shadow behind exploded slice
        final shadowPaint = Paint()
          ..color = Color(item.category.colorHex).withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(center: segmentCenter, radius: arcRadius),
          startAngle + gap / 2,
          math.max(0.001, sweepAngle - gap),
          false,
          shadowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: segmentCenter, radius: arcRadius),
        startAngle + gap / 2,
        math.max(0.001, sweepAngle - gap),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw Center Hole Text Info
    _drawCenterHole(canvas, center);
  }

  void _drawCenterHole(Canvas canvas, Offset center) {
    final title = selectedItem != null
        ? selectedItem!.category.name
        : 'Total Spent';

    final amountText = selectedItem != null
        ? _formatCurrency(selectedItem!.totalAmount)
        : _formatCurrency(totalAmount);

    final subtext = selectedItem != null
        ? '${selectedItem!.percentage.toStringAsFixed(1)}% of total'
        : '${data.length} categories';

    // Center Title Text
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);

    // Center Amount Text
    final amountPainter = TextPainter(
      text: TextSpan(
        text: amountText,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 130);

    // Center Subtext
    final subtextPainter = TextPainter(
      text: TextSpan(
        text: subtext,
        style: TextStyle(
          fontSize: 11,
          color: selectedItem != null
              ? Color(selectedItem!.category.colorHex)
              : Colors.blueGrey,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);

    final totalHeight = titlePainter.height + amountPainter.height + subtextPainter.height + 6;
    var currentY = center.dy - totalHeight / 2;

    titlePainter.paint(canvas, Offset(center.dx - titlePainter.width / 2, currentY));
    currentY += titlePainter.height + 2;

    amountPainter.paint(canvas, Offset(center.dx - amountPainter.width / 2, currentY));
    currentY += amountPainter.height + 2;

    subtextPainter.paint(canvas, Offset(center.dx - subtextPainter.width / 2, currentY));
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000) {
      final intVal = amount.round();
      final str = intVal.toString();
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
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data;
  }
}
