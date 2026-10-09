import '../models/receipt.dart';
import '../models/category.dart';

/// Utility to export receipt transactions and category summaries to standard CSV format
class ExpenseCsvExporter {
  /// Converts a list of receipts into an RFC 4180 compliant CSV string
  static String exportToCsv(List<Receipt> receipts) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('ID,Date,Merchant,Category,TotalAmount,Currency,ItemCount,Notes');

    for (final receipt in receipts) {
      final id = receipt.id ?? 0;
      final date = receipt.formattedDate;
      final merchant = _escapeCsv(receipt.merchant);
      final category = _escapeCsv(receipt.category.name);
      final amount = receipt.totalAmount.toStringAsFixed(2);
      final currency = receipt.currency;
      final itemCount = receipt.items.length;
      final notes = _escapeCsv(receipt.notes ?? '');

      buffer.writeln('$id,$date,$merchant,$category,$amount,$currency,$itemCount,$notes');
    }

    return buffer.toString();
  }

  /// Generates a category summary CSV breakdown
  static String generateCategorySummaryCsv(List<Receipt> receipts) {
    final buffer = StringBuffer();
    buffer.writeln('CategoryID,CategoryName,TotalAmount,TransactionCount,Percentage');

    if (receipts.isEmpty) return buffer.toString();

    final catTotals = <String, double>{};
    final catCounts = <String, int>{};
    double grandTotal = 0.0;

    for (final r in receipts) {
      catTotals[r.categoryId] = (catTotals[r.categoryId] ?? 0.0) + r.totalAmount;
      catCounts[r.categoryId] = (catCounts[r.categoryId] ?? 0) + 1;
      grandTotal += r.totalAmount;
    }

    catTotals.forEach((catId, total) {
      final cat = ExpenseCategory.fromId(catId);
      final count = catCounts[catId] ?? 0;
      final pct = grandTotal > 0 ? (total / grandTotal * 100).toStringAsFixed(2) : '0.00';
      buffer.writeln('$catId,${_escapeCsv(cat.name)},${total.toStringAsFixed(2)},$count,$pct%');
    });

    return buffer.toString();
  }

  /// Escapes CSV values containing commas, quotes, or newlines
  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
