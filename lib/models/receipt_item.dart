/// Individual line item extracted or entered for a receipt
class ReceiptItem {
  final int? id;
  final int? receiptId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? rawLine;

  const ReceiptItem({
    this.id,
    this.receiptId,
    required this.name,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    required this.totalPrice,
    this.rawLine,
  });

  ReceiptItem copyWith({
    int? id,
    int? receiptId,
    String? name,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? rawLine,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      rawLine: rawLine ?? this.rawLine,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (receiptId != null) 'receipt_id': receiptId,
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'raw_line': rawLine,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      id: map['id'] as int?,
      receiptId: map['receipt_id'] as int?,
      name: map['name'] as String? ?? 'Item',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      rawLine: map['raw_line'] as String?,
    );
  }
}

