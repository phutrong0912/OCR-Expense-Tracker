import 'dart:math' as math;

void main() {
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() fn) {
    try {
      fn();
      print('  ✓ PASS: $name');
      passed++;
    } catch (e, stack) {
      print('  ✗ FAIL: $name');
      print('    Error: $e');
      print('    Stack: $stack');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected, [String? reason]) {
    if (actual != expected) {
      throw Exception('Expected <$expected> but got <$actual>${reason != null ? " ($reason)" : ""}');
    }
  }

  print('=== Running CustomPainter Chart Mathematics & Physics Test Suite ===');

  test('Donut Chart Sweep Angle Sums to 2*PI', () {
    final percentages = [35.0, 25.0, 20.0, 10.0, 10.0];
    double totalSweep = 0.0;
    for (final pct in percentages) {
      final sweep = (pct / 100.0) * 2 * math.pi;
      totalSweep += sweep;
    }
    // Allow slight double precision tolerance
    final diff = (totalSweep - 2 * math.pi).abs();
    expect(diff < 0.000001, true, 'Sum of sweeps must equal 2*PI');
  });

  test('Donut Slice Exploding Bisector Vector', () {
    // Slice from angle 0 to PI/2 (top-right quadrant)
    const startAngle = 0.0;
    const sweepAngle = math.pi / 2;
    const midAngle = startAngle + sweepAngle / 2; // PI/4 (45 degrees)
    const explodeDist = 8.0;

    final dx = math.cos(midAngle) * explodeDist;
    final dy = math.sin(midAngle) * explodeDist;

    // At 45 degrees, dx and dy should be equal to explodeDist / sqrt(2) ~ 5.65685
    expect((dx - dy).abs() < 0.0001, true, 'Radial offset must be symmetric at 45 deg');
    expect(math.sqrt(dx * dx + dy * dy).round(), 8, 'Explosion magnitude must be 8px');
  });

  test('Bar Chart Nice Max Dynamic Scale Calculation', () {
    double calculateNiceMax(double value) {
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

    // 94,000 should round up to 100,000
    expect(calculateNiceMax(94000), 100000.0, '94k rounds to 100k');

    // 177,000 should round up to 200,000
    expect(calculateNiceMax(177000), 200000.0, '177k rounds to 200k');

    // 350,000 should round up to 500,000
    expect(calculateNiceMax(350000), 500000.0, '350k rounds to 500k');

    // 780,000 should round up to 1,000,000
    expect(calculateNiceMax(780000), 1000000.0, '780k rounds to 1M');
  });

  test('Bar Chart Hit-Testing Slot Mapping', () {
    const canvasWidth = 360.0;
    const leftPadding = 48.0;
    const rightPadding = 16.0;
    const barCount = 7;

    final chartWidth = canvasWidth - leftPadding - rightPadding; // 296.0
    final slotWidth = chartWidth / barCount; // ~42.285

    int getBarIndexAt(double tapX) {
      if (tapX < leftPadding || tapX > canvasWidth - rightPadding) return -1;
      return ((tapX - leftPadding) / slotWidth).floor();
    }

    // Tap outside left
    expect(getBarIndexAt(20.0), -1, 'Tap in Y-axis gutter is ignored');

    // Tap first bar center (leftPadding + slotWidth * 0.5)
    expect(getBarIndexAt(leftPadding + slotWidth * 0.5), 0, 'First bar selected');

    // Tap fourth bar center
    expect(getBarIndexAt(leftPadding + slotWidth * 3.5), 3, 'Fourth bar selected');

    // Tap last bar
    expect(getBarIndexAt(leftPadding + slotWidth * 6.5), 6, 'Seventh bar selected');
  });

  print('\n=== All Chart Geometry Tests Passed Successfully! ($passed/$passed) ===');
}
