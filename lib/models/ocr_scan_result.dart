import 'category.dart';
import 'receipt_item.dart';

/// Represents a single text line or recognized segment with spatial bounding box
class OcrBoundingElement {
  final String text;
  final double top;
  final double left;
  final double width;
  final double height;
  final double confidence;

  const OcrBoundingElement({
    required this.text,
    this.top = 0.0,
    this.left = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    this.confidence = 1.0,
  });
}

/// Structured result of ML Kit OCR execution and Heuristic Parsing
class OcrScanResult {
  final String rawText;
  final List<String> lines;
  final List<OcrBoundingElement> boundingElements;
  final String? extractedMerchant;
  final double? extractedTotal;
  final String extractedCurrency;
  final DateTime? extractedDate;
  final ExpenseCategory detectedCategory;
  final List<ReceiptItem> extractedItems;
  final Map<String, double> confidenceScores;

  const OcrScanResult({
    required this.rawText,
    required this.lines,
    this.boundingElements = const [],
    this.extractedMerchant,
    this.extractedTotal,
    this.extractedCurrency = 'VND',
    this.extractedDate,
    required this.detectedCategory,
    this.extractedItems = const [],
    this.confidenceScores = const {},
  });

  bool get hasValidTotal => extractedTotal != null && extractedTotal! > 0;
  bool get hasValidMerchant => extractedMerchant != null && extractedMerchant!.trim().isNotEmpty;
  bool get hasValidDate => extractedDate != null;

  double get overallConfidence {
    if (confidenceScores.isEmpty) return 0.5;
    final sum = confidenceScores.values.fold(0.0, (prev, elem) => prev + elem);
    return sum / confidenceScores.length;
  }
}

