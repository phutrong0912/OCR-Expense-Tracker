/// Core ExpenseCategory model with decoupled color and icon definitions
class ExpenseCategory {
  final String id;
  final String name;
  final int iconCode;
  final int colorHex;
  final List<String> keywords;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorHex,
    required this.keywords,
  });

  static const List<ExpenseCategory> predefined = [
    ExpenseCategory(
      id: 'food',
      name: 'Food & Dining',
      iconCode: 0xe532, // restaurant
      colorHex: 0xFFEF4444, // Vibrant Red
      keywords: [
        'cafe', 'coffee', 'phúc long', 'highlands', 'starbucks', 'the coffee house',
        'kfc', 'lotteria', 'mcdonald', 'pizza', 'burger', 'phở', 'bún', 'cơm',
        'trà sữa', 'tiệm ăn', 'nhà hàng', 'quán ăn', 'bánh mì', 'food', 'restaurant',
        'dining', 'lunch', 'dinner', 'breakfast', 'tea', 'bakery', 'milktea', 'toco'
      ],
    ),
    ExpenseCategory(
      id: 'study',
      name: 'Study & Books',
      iconCode: 0xe3e0, // menu_book
      colorHex: 0xFF3B82F6, // Vibrant Blue
      keywords: [
        'fahasa', 'nhà sách', 'bookstore', 'stationery', 'văn phòng phẩm',
        'photo', 'in ấn', 'giáo trình', 'sách', 'vở', 'bút', 'thư viện',
        'học phí', 'khóa học', 'coursera', 'udemy', 'study', 'university', 'college'
      ],
    ),
    ExpenseCategory(
      id: 'travel',
      name: 'Travel & Commute',
      iconCode: 0xe1d7, // directions_car
      colorHex: 0xFFF59E0B, // Vibrant Amber
      keywords: [
        'grab', 'be', 'gojek', 'xăng', 'petrolimex', 'petro', 'vé xe', 'bus',
        'vé tàu', 'vé máy bay', 'flight', 'airline', 'taxi', 'parking',
        'gửi xe', 'toll', 'travel', 'transport', 'hotel', 'motel', 'airbnb'
      ],
    ),
    ExpenseCategory(
      id: 'gear',
      name: 'Gear & Tech',
      iconCode: 0xe1e8, // devices
      colorHex: 0xFF8B5CF6, // Vibrant Purple
      keywords: [
        'thế giới di động', 'fpt shop', 'cellphones', 'gearvn', 'gear', 'tech',
        'phụ kiện', 'tai nghe', 'cáp sạc', 'chuột', 'bàn phím', 'laptop', 'phone',
        'electronics', 'usb', 'ram', 'ssd', 'shopee', 'lazada', 'tiki'
      ],
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Entertainment',
      iconCode: 0xe406, // movie
      colorHex: 0xFFEC4899, // Vibrant Pink
      keywords: [
        'cgv', 'bhd', 'lotte cinema', 'galaxy cinema', 'cinema', 'phim', 'rạp',
        'game', 'steam', 'netflix', 'spotify', 'karaoke', 'billiard', 'bowling',
        'concert', 'vé xem', 'amusement', 'entertainment'
      ],
    ),
    ExpenseCategory(
      id: 'groceries',
      name: 'Groceries & Market',
      iconCode: 0xe59c, // shopping_cart
      colorHex: 0xFF10B981, // Vibrant Green
      keywords: [
        'co.opmart', 'winmart', 'bách hóa xanh', 'circle k', '7-eleven', 'family mart',
        'gs25', 'siêu thị', 'mart', 'supermarket', 'market', 'chợ', 'tiện lợi',
        'minimart', 'grocery', 'tiêu dùng', 'sữa', 'rau củ', 'thịt'
      ],
    ),
    ExpenseCategory(
      id: 'other',
      name: 'General / Other',
      iconCode: 0xe50e, // receipt_long
      colorHex: 0xFF6B7280, // Slate Gray
      keywords: ['khác', 'dịch vụ', 'service', 'general', 'other', 'misc'],
    ),
  ];

  static ExpenseCategory fromId(String? id) {
    if (id == null) return predefined.last;
    return predefined.firstWhere(
      (cat) => cat.id.toLowerCase() == id.toLowerCase(),
      orElse: () => predefined.last,
    );
  }

  /// Automatically infers the category based on text keyword matching with boundary isolation
  static ExpenseCategory detectFromText(String text) {
    final lower = text.toLowerCase();

    // Check specific high-priority keywords
    for (final category in predefined) {
      if (category.id == 'other') continue;
      for (final kw in category.keywords) {
        final escaped = RegExp.escape(kw.toLowerCase());
        final pattern = RegExp('(^|[^a-z0-9_à-ỹ])' + escaped + '([^a-z0-9_à-ỹ]|\$)', caseSensitive: false);
        if (pattern.hasMatch(lower)) {
          return category;
        }
      }
    }

    // Secondary substring check for brands with symbols (e.g. Co.opmart, WinMart+)
    for (final category in predefined) {
      if (category.id == 'other') continue;
      for (final kw in category.keywords) {
        if (kw.length >= 4 && lower.contains(kw.toLowerCase())) {
          return category;
        }
      }
    }

    return predefined.last;
  }
}
