import '../lib/models/receipt.dart';
import '../lib/models/receipt_item.dart';
import '../lib/utils/csv_exporter.dart';

void main() {
  int passed = 0;

  void test(String name, void Function() fn) {
    try {
      fn();
      print('  ✓ PASS: $name');
      passed++;
    } catch (e, stack) {
      print('  ✗ FAIL: $name');
      print('    Error: $e');
      print('    Stack: $stack');
      rethrow;
    }
  }

  void expect(dynamic actual, dynamic expected, [String? reason]) {
    if (actual != expected) {
      throw Exception('Expected <$expected> but got <$actual>${reason != null ? " ($reason)" : ""}');
    }
  }

  print('=== Running Expense CSV Exporter Tests ===');

  test('Export list of receipts to CSV format', () {
    final receipts = [
      Receipt(
        id: 1,
        merchant: 'Highlands Coffee',
        totalAmount: 94000,
        currency: 'VND',
        date: DateTime(2026, 10, 8),
        categoryId: 'food',
        notes: 'Coffee with friends',
        items: [
          const ReceiptItem(name: 'Phin Sữa Đá', totalPrice: 39000),
          const ReceiptItem(name: 'Trà Sen Vàng', totalPrice: 55000),
        ],
      ),
      Receipt(
        id: 2,
        merchant: 'Circle K, Store #42',
        totalAmount: 25000,
        currency: 'VND',
        date: DateTime(2026, 10, 8),
        categoryId: 'groceries',
        notes: 'Quick snack',
      ),
    ];

    final csv = ExpenseCsvExporter.exportToCsv(receipts);
    expect(csv.contains('ID,Date,Merchant,Category,TotalAmount,Currency,ItemCount,Notes'), true);
    expect(csv.contains('1,08/10/2026,Highlands Coffee,Food & Dining,94000.00,VND,2,Coffee with friends'), true);
    // Verified CSV comma escaping for 'Circle K, Store #42'
    expect(csv.contains('"Circle K, Store #42"'), true);
  });

  test('Export category summary CSV breakdown', () {
    final receipts = [
      Receipt(
        id: 1,
        merchant: 'Highlands',
        totalAmount: 100000,
        date: DateTime(2026, 10, 8),
        categoryId: 'food',
      ),
      Receipt(
        id: 2,
        merchant: 'Fahasa',
        totalAmount: 100000,
        date: DateTime(2026, 10, 8),
        categoryId: 'study',
      ),
    ];

    final summaryCsv = ExpenseCsvExporter.generateCategorySummaryCsv(receipts);
    expect(summaryCsv.contains('CategoryID,CategoryName,TotalAmount,TransactionCount,Percentage'), true);
    expect(summaryCsv.contains('food,Food & Dining,100000.00,1,50.00%'), true);
    expect(summaryCsv.contains('study,Study & Books,100000.00,1,50.00%'), true);
  });

  print('\n=== All CSV Exporter Tests Passed! ($passed/$passed) ===');
}
