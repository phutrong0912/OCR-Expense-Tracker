import 'category.dart';
import 'receipt_item.dart';

/// Primary Receipt model representing a parsed transaction record
class Receipt {
  final int? id;
  final String merchant;
  final double totalAmount;
  final String currency;
  final DateTime date;
  final String categoryId;
  final String? imagePath;
  final String? thumbnailPath;
  final String? rawOcrText;
  final String? notes;
  final DateTime createdAt;
  final List<ReceiptItem> items;

  Receipt({
    this.id,
    required this.merchant,
    required this.totalAmount,
    this.currency = 'VND',
    required this.date,
    required this.categoryId,
    this.imagePath,
    this.thumbnailPath,
    this.rawOcrText,
    this.notes,
    DateTime? createdAt,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  ExpenseCategory get category => ExpenseCategory.fromId(categoryId);

  /// Formatted monetary total (handles VND integer dot-grouping or USD decimal)
  String get formattedAmount {
    if (currency == 'VND' || currency == 'đ' || currency == '₫') {
      final intVal = totalAmount.round().abs();
      final str = intVal.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(str[i]);
      }
      return '${totalAmount < 0 ? "-" : ""}${buffer.toString()} ₫';
    } else {
      return '\$${totalAmount.toStringAsFixed(2)}';
    }
  }

  /// Compact formatted date (DD/MM/YYYY)
  String get formattedDate {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  /// Detailed date and time string (DD/MM/YYYY HH:mm)
  String get formattedDateTime {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  Receipt copyWith({
    int? id,
    String? merchant,
    double? totalAmount,
    String? currency,
    DateTime? date,
    String? categoryId,
    String? imagePath,
    String? thumbnailPath,
    String? rawOcrText,
    String? notes,
    DateTime? createdAt,
    List<ReceiptItem>? items,
  }) {
    return Receipt(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'merchant': merchant,
      'total_amount': totalAmount,
      'currency': currency,
      'date': date.toIso8601String(),
      'category_id': categoryId,
      'image_path': imagePath,
      'thumbnail_path': thumbnailPath,
      'raw_ocr_text': rawOcrText,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map, {List<ReceiptItem> items = const []}) {
    return Receipt(
      id: map['id'] as int?,
      merchant: map['merchant'] as String? ?? 'Unknown Merchant',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'VND',
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      categoryId: map['category_id'] as String? ?? 'other',
      imagePath: map['image_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      items: items,
    );
  }
}
