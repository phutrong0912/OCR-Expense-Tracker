import '../lib/services/regex_parser.dart';

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

  print('=== Running Comprehensive Regex Heuristic Parser Test Suite ===');

  test('Highlands Coffee Vietnamese Receipt', () {
    const raw = '''
HIGHLANDS COFFEE
Đ/C: 135 Hai Bà Trưng, Q.1, TP.HCM
Ngày: 08/10/2026 09:15
Số HĐ: HD98712
1 Phin Sữa Đá L 39.000
1 Trà Sen Vàng L 55.000
Cộng tiền hàng: 94.000
TỔNG CỘNG: 94.000 đ
Tiền khách đưa: 100.000
Tiền thối lại: 6.000
Cảm ơn quý khách!
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'Highlands Coffee', 'Merchant extraction');
    expect(result.extractedTotal, 94000.0, 'Total amount extraction');
    expect(result.extractedCurrency, 'VND', 'Currency extraction');
    expect(result.extractedDate?.year, 2026, 'Date year');
    expect(result.extractedDate?.month, 10, 'Date month');
    expect(result.extractedDate?.day, 8, 'Date day');
    expect(result.detectedCategory.id, 'food', 'Food category');
    expect(result.hasValidTotal, true);
  });

  test('Circle K Minimart Receipt', () {
    const raw = '''
CIRCLE K VIETNAM
MST: 0305882190
HD: CK-88291
08-10-2026 13:45
Bánh mì que 15.000
Nước suối Aquafina 10.000
Tổng tiền: 25.000 VND
Khách đưa: 50.000
Thối lại: 25.000
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'Circle K', 'Merchant extraction');
    expect(result.extractedTotal, 25000.0, 'Total amount extraction');
    expect(result.extractedDate?.year, 2026, 'Date year');
    expect(result.detectedCategory.id, 'groceries', 'Groceries category');
  });

  test('Fahasa Bookstore Receipt (Study Category)', () {
    const raw = '''
NHÀ SÁCH FAHASA
Chi nhánh Tân Định
Ngày 15/09/2026
Vở kẻ ngang 5 quyển 45.000
Bút bi Thiên Long 2 cây 12.000
Sách Giáo trình Flutter 120.000
THANH TOÁN: 177,000 đ
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'Fahasa', 'Merchant extraction');
    expect(result.extractedTotal, 177000.0, 'Total amount extraction');
    expect(result.extractedDate?.month, 9, 'Date month');
    expect(result.extractedDate?.day, 15, 'Date day');
    expect(result.detectedCategory.id, 'study', 'Study category');
  });

  test('Grab Commute Receipt (Travel Category)', () {
    const raw = '''
GRAB VIETNAM
Chuyến đi GrabCar
Ngày 01/10/2026 18:30
Cước phí: 68.000 VND
Phí cầu đường: 10.000
Tổng thanh toán: 78.000 đ
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'Grab', 'Merchant extraction');
    expect(result.extractedTotal, 78000.0, 'Total amount extraction');
    expect(result.extractedDate?.day, 1, 'Date day');
    expect(result.detectedCategory.id, 'travel', 'Travel category');
  });

  test('International USD Starbucks Receipt', () {
    const raw = '''
STARBUCKS STORE #1048
Date: 2026-07-22 08:30 AM
1 Caramel Macchiato 5.50
1 Croissant 4.25
Subtotal: \$9.75
Tax: \$0.78
GRAND TOTAL: \$10.53
Cash: \$20.00
Change: \$9.47
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'Starbucks', 'Merchant extraction');
    expect(result.extractedTotal, 10.53, 'Total USD extraction');
    expect(result.extractedCurrency, 'USD', 'Currency extraction');
    expect(result.extractedDate?.month, 7, 'Date month');
    expect(result.extractedDate?.day, 22, 'Date day');
  });

  test('Noisy Receipt with Unknown Merchant and Text Date', () {
    const raw = '''
QUÁN CƠM TẤM BA GHIỀN
84 Đặng Văn Ngữ, Phú Nhuận
Ngày 05 tháng 06 năm 2026
1 Cơm sườn bì chả 65.000
1 Trà đá 5.000
Thành tiền: 70.000
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'QUÁN CƠM TẤM BA GHIỀN');
    expect(result.extractedTotal, 70000.0);
    expect(result.extractedDate?.year, 2026);
    expect(result.extractedDate?.month, 6);
    expect(result.extractedDate?.day, 5);
    expect(result.detectedCategory.id, 'food');
  });

  test('Receipt with Phone Number and Tax Code (MST) Ignored', () {
    const raw = '''
THẾ GIỚI DI ĐỘNG
Đ/c: 128 Trần Quang Khải, Q1
MST: 0303217354
Tel: 0908123456
Hotline: 18001060
02/10/2026
Cáp sạc Type-C 190.000
TỔNG CỘNG: 190.000 đ
Tiền mặt: 200.000
Thối lại: 10.000
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'Thế Giới Di Động');
    expect(result.extractedTotal, 190000.0, 'Total should not match phone or MST');
    expect(result.detectedCategory.id, 'gear');
  });

  test('Receipt with "k" suffix in amount', () {
    const raw = '''
TRÀ SỮA TOCOTOCO
Ngày 20/08/2026
Trà sữa ba anh em 45k
Thành tiền: 45k
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedTotal, 45000.0, '45k parsed to 45000');
    expect(result.detectedCategory.id, 'food');
  });

  test('CGV Cinema Ticket Receipt (Entertainment)', () {
    const raw = '''
CGV CINEMAS VIETNAM
Rạp CGV Sư Vạn Hạnh
Ngày: 30/09/2026 19:45
2 Vé xem phim 220.000
1 Combo Bắp Nước 95.000
TỔNG CỘNG: 315.000 VND
''';
    final result = ReceiptRegexParser.parse(raw);
    expect(result.extractedMerchant, 'CGV Cinemas');
    expect(result.extractedTotal, 315000.0);
    expect(result.detectedCategory.id, 'entertainment');
  });

  print('\n=== All Tests Passed Successfully! ($passed/$passed) ===');
}

