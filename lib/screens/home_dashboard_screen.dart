import 'dart:io';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/receipt.dart';
import '../database/db_helper.dart';
import '../widgets/charts/animated_bar_chart.dart';
import 'scanner_screen.dart';
import 'analytics_screen.dart';
import 'receipt_history_screen.dart';
import 'receipt_detail_screen.dart';

/// Home Dashboard Screen: Primary interface for students & club treasurers
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<Receipt> _recentReceipts = [];
  List<DailySpending> _weeklyData = [];
  double _monthlyTotal = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    // Seed mock data if database is empty on first launch
    await DatabaseHelper.instance.seedInitialData();

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final receipts = await DatabaseHelper.instance.getAllReceipts();
    final weekly = await DatabaseHelper.instance.getWeeklySpendingSummary();

    double monthTotal = 0.0;
    for (final r in receipts) {
      if (r.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))) {
        monthTotal += r.totalAmount;
      }
    }

    if (mounted) {
      setState(() {
        _recentReceipts = receipts.take(5).toList();
        _weeklyData = weekly;
        _monthlyTotal = monthTotal;
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

  Future<void> _openScanner() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.document_scanner, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'OCR Expense Tracker',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Spending Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Receipt Records',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
              ).then((_) => _loadDashboardData());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Executive Summary Spending Card
                  _buildMonthlySummaryCard(),
                  const SizedBox(height: 20),

                  // 2. Weekly Spending Canvas Preview (CustomPainter)
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weekly Spending Trend',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Canvas CustomPainter chart',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                                  );
                                },
                                child: const Text('View All Charts'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedBarChart(data: _weeklyData, height: 180),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Quick Category Tiles
                  _buildCategoryQuickGrid(),
                  const SizedBox(height: 20),

                  // 4. Recent Verified Receipts Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Receipts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
                          ).then((_) => _loadDashboardData());
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 5. Recent Receipts List
                  if (_recentReceipts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No receipts parsed yet. Tap the camera to scan one!'),
                        ],
                      ),
                    )
                  else
                    ..._recentReceipts.map((receipt) => _buildReceiptItemCard(receipt)),
                  const SizedBox(height: 60),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMonthlySummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH\'S EXPENSES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'On-Device AI',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatVnd(_monthlyTotal),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.document_scanner, size: 18),
                  label: const Text('Quick Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    );
                  },
                  icon: const Icon(Icons.pie_chart_outline, size: 18, color: Colors.white),
                  label: const Text('Analytics', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryQuickGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Expense Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ExpenseCategory.predefined.take(5).map((cat) {
              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(cat.colorHex).withOpacity(0.12),
                      child: Icon(
                        IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                        size: 18,
                        color: Color(cat.colorHex),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.name.split(' ').first,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

  Widget _buildReceiptItemCard(Receipt receipt) {
    final cat = receipt.category;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReceiptDetailScreen(
                receipt: receipt,
                onReceiptUpdated: _loadDashboardData,
              ),
            ),
          );
          _loadDashboardData();
        },
        leading: (receipt.thumbnailPath != null && File(receipt.thumbnailPath!).existsSync())
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(receipt.thumbnailPath!),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            : CircleAvatar(
                backgroundColor: Color(cat.colorHex).withOpacity(0.12),
                child: Icon(
                  IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                  color: Color(cat.colorHex),
                  size: 20,
                ),
              ),
        title: Text(
          receipt.merchant,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${cat.name} • ${receipt.formattedDate}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Text(
          receipt.formattedAmount,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }
}

