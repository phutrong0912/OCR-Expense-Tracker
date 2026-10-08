import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../widgets/charts/animated_donut_chart.dart';
import '../widgets/charts/animated_bar_chart.dart';

/// Analytics Screen hosting pure CustomPainter Donut and Bar charts
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'all'; // 'week', 'month', 'all'
  List<CategorySpending> _categoryData = [];
  List<DailySpending> _weeklyData = [];
  bool _isLoading = true;
  double _totalSpent = 0.0;
  int _receiptCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    DateTime? startDate;

    if (_selectedPeriod == 'week') {
      startDate = now.subtract(const Duration(days: 7));
    } else if (_selectedPeriod == 'month') {
      startDate = DateTime(now.year, now.month, 1);
    }

    final catSummary = await DatabaseHelper.instance.getCategorySpendingSummary(
      startDate: startDate,
    );
    final weekSummary = await DatabaseHelper.instance.getWeeklySpendingSummary();
    final allReceipts = await DatabaseHelper.instance.getAllReceipts(
      startDate: startDate,
    );

    double total = 0.0;
    for (final r in allReceipts) {
      total += r.totalAmount;
    }

    if (mounted) {
      setState(() {
        _categoryData = catSummary;
        _weeklyData = weekSummary;
        _totalSpent = total;
        _receiptCount = allReceipts.length;
        _isLoading = false;
      });
    }
  }

  String _formatVnd(double amount) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period Selector Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPeriodChip('This Week', 'week'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('This Month', 'month'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('All Time', 'all'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Overview Metric Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Spending',
                          _formatVnd(_totalSpent),
                          Icons.account_balance_wallet,
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Receipts Parsed',
                          '$_receiptCount records',
                          Icons.receipt_long,
                          const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Weekly Spending Bar Chart Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bar_chart, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text(
                                'Weekly Daily Spending Trend',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pure CustomPainter canvas with average threshold line',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBarChart(data: _weeklyData),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Category Donut Chart Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart, color: Color(0xFF8B5CF6)),
                              SizedBox(width: 8),
                              Text(
                                'Category Expenditure Distribution',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Interactive touch-to-explode slice visualization (CustomPainter)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          AnimatedDonutChart(data: _categoryData),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Category Breakdown List
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category Share Breakdown',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_categoryData.isEmpty)
                            const Center(child: Text('No categories recorded yet'))
                          else
                            ..._categoryData.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              IconData(cat.category.iconCode, fontFamily: 'MaterialIcons'),
                                              size: 18,
                                              color: Color(cat.category.colorHex),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              cat.category.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${_formatVnd(cat.totalAmount)} (${cat.percentage.toStringAsFixed(1)}%)',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: cat.percentage / 100.0,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(cat.category.colorHex),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodChip(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedPeriod = period;
          });
          _loadAnalytics();
        }
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
