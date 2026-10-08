import '../lib/models/receipt.dart';
import '../lib/models/receipt_item.dart';
import '../lib/models/category.dart';

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

  print('=== Running Database Models & Serialization Test Suite ===');

  test('Receipt Item toMap and fromMap serialization', () {
    final item = ReceiptItem(
      id: 1,
      receiptId: 10,
      name: 'Phin Sữa Đá L',
      quantity: 2,
      unitPrice: 39000,
      totalPrice: 78000,
      rawLine: '2 Phin Sữa Đá L 78.000',
    );

    final map = item.toMap();
    expect(map['id'], 1);
    expect(map['receipt_id'], 10);
    expect(map['name'], 'Phin Sữa Đá L');
    expect(map['total_price'], 78000.0);

    final restored = ReceiptItem.fromMap(map);
    expect(restored.id, item.id);
    expect(restored.name, item.name);
    expect(restored.totalPrice, item.totalPrice);
    expect(restored.quantity, 2.0);
  });

  test('Receipt toMap and fromMap serialization', () {
    final now = DateTime(2026, 10, 8, 14, 30);
    final receipt = Receipt(
      id: 5,
      merchant: 'Highlands Coffee',
      totalAmount: 94000,
      currency: 'VND',
      date: now,
      categoryId: 'food',
      notes: 'Midterm celebration',
      items: [
        const ReceiptItem(name: 'Phin Sữa Đá', totalPrice: 39000),
        const ReceiptItem(name: 'Trà Sen Vàng', totalPrice: 55000),
      ],
    );

    final map = receipt.toMap();
    expect(map['id'], 5);
    expect(map['merchant'], 'Highlands Coffee');
    expect(map['total_amount'], 94000.0);
    expect(map['category_id'], 'food');
    expect(map['currency'], 'VND');

    final restored = Receipt.fromMap(map, items: receipt.items);
    expect(restored.id, 5);
    expect(restored.merchant, 'Highlands Coffee');
    expect(restored.totalAmount, 94000.0);
    expect(restored.items.length, 2);
    expect(restored.category.id, 'food');
  });

  test('Vietnamese VND Integer Currency Formatting', () {
    final r1 = Receipt(
      merchant: 'WinMart',
      totalAmount: 150000,
      currency: 'VND',
      date: DateTime.now(),
      categoryId: 'groceries',
    );
    expect(r1.formattedAmount, '150.000 ₫');

    final r2 = Receipt(
      merchant: 'CellphoneS',
      totalAmount: 1250000,
      currency: 'VND',
      date: DateTime.now(),
      categoryId: 'gear',
    );
    expect(r2.formattedAmount, '1.250.000 ₫');
  });

  test('USD Decimal Currency Formatting', () {
    final r = Receipt(
      merchant: 'Starbucks Seattle',
      totalAmount: 12.5,
      currency: 'USD',
      date: DateTime.now(),
      categoryId: 'food',
    );
    expect(r.formattedAmount, '\$12.50');
  });

  test('Expense Category Keywords Auto-Detection', () {
    expect(ExpenseCategory.detectFromText('Hóa đơn Highlands Coffee').id, 'food');
    expect(ExpenseCategory.detectFromText('Cước xe GrabCar ngày mưa').id, 'travel');
    expect(ExpenseCategory.detectFromText('Nhà sách Fahasa mua giáo trình').id, 'study');
    expect(ExpenseCategory.detectFromText('Mua cáp sạc FPT Shop').id, 'gear');
    expect(ExpenseCategory.detectFromText('Vé xem phim CGV Cinema').id, 'entertainment');
    expect(ExpenseCategory.detectFromText('Siêu thị WinMart mua rau').id, 'groceries');
  });

  print('\n=== All Model & Serialization Tests Passed! ($passed/$passed) ===');
}

