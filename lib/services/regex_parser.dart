import 'dart:math' as math;
import '../models/category.dart';
import '../models/ocr_scan_result.dart';
import '../models/receipt_item.dart';

/// Heuristic Regex Engine for Offline Parsing of Noisy OCR Receipts
class ReceiptRegexParser {
  // Known Vietnamese & International Retail / Dining Chains
  static const List<String> _knownMerchants = [
    'Highlands Coffee', 'Phúc Long', 'The Coffee House', 'Starbucks',
    'Trung Nguyên Legend', 'KFC', 'Lotteria', 'Jollibee', 'McDonald\'s',
    'Pizza Hut', 'The Pizza Company', 'Dominos Pizza', 'Phở 24',
    'Gogi House', 'Kichi Kichi', 'Manwah', 'Haidilao', 'Dookki',
    'Circle K', '7-Eleven', 'FamilyMart', 'GS25', 'Ministop',
    'WinMart', 'WinMart+', 'Co.opmart', 'Co.op Food', 'Bách Hóa Xanh',
    'Big C', 'GO!', 'Aeon Mall', 'Lotte Mart', 'Mega Market',
    'Fahasa', 'Nhà Sách Phương Nam', 'Tiến Thọ', 'Cá Chép',
    'Thế Giới Di Động', 'Điện Máy Xanh', 'FPT Shop', 'CellphoneS', 'GearVN',
    'CGV Cinemas', 'Lotte Cinema', 'BHD Star', 'Galaxy Cinema',
    'Grab', 'Be', 'Gojek', 'Petrolimex', 'PVOIL',
  ];

  // Specific merchant to category mapping overrides
  static const Map<String, String> _merchantCategoryOverrides = {
    'circle k': 'groceries',
    '7-eleven': 'groceries',
    'familymart': 'groceries',
    'gs25': 'groceries',
    'ministop': 'groceries',
    'winmart': 'groceries',
    'winmart+': 'groceries',
    'co.opmart': 'groceries',
    'co.op food': 'groceries',
    'bách hóa xanh': 'groceries',
    'big c': 'groceries',
    'go!': 'groceries',
    'lotte mart': 'groceries',
    'mega market': 'groceries',
    'fahasa': 'study',
    'nhà sách phương nam': 'study',
    'tiến thọ': 'study',
    'cá chép': 'study',
    'grab': 'travel',
    'be': 'travel',
    'gojek': 'travel',
    'petrolimex': 'travel',
    'pvoil': 'travel',
    'thế giới di động': 'gear',
    'fpt shop': 'gear',
    'cellphones': 'gear',
    'gearvn': 'gear',
    'cgv cinemas': 'entertainment',
    'lotte cinema': 'entertainment',
    'bhd star': 'entertainment',
    'galaxy cinema': 'entertainment',
  };

  // Noise lines to discard when searching for merchant
  static final List<RegExp> _merchantNoisePatterns = [
    RegExp(r'h[oó][aá]\s*đ[oơ]n', caseSensitive: false),
    RegExp(r'phi[eế]u\s*thanh\s*to[aá]n', caseSensitive: false),
    RegExp(r'phi[eế]u\s*t[ií]nh\s*ti[eề]n', caseSensitive: false),
    RegExp(r'receipt|tax\s*invoice|bill|sales\s*receipt', caseSensitive: false),
    RegExp(r'welcome|xin\s*ch[aà]o|c[aả]m\s*[oơ]n\s*qu[yý]\s*kh[aá]ch', caseSensitive: false),
    RegExp(r'm[aã]\s*s[oố]\s*thu[eế]|mst[:\s]', caseSensitive: false),
    RegExp(r'đ[iị]a\s*ch[iỉ]|address|đ\/c[:\s]', caseSensitive: false),
    RegExp(r'tel[:\s]|s[dđ]t[:\s]|phone|hotline', caseSensitive: false),
    RegExp(r'https?:\/\/|www\.|\.vn|\.com', caseSensitive: false),
  ];

  // High-confidence Total Amount indicator keywords
  static final List<RegExp> _totalKeywords = [
    RegExp(r'grand\s*total', caseSensitive: false),
    RegExp(r't[oổ]ng\s*c[oộ]ng', caseSensitive: false),
    RegExp(r'th[aà]nh\s*ti[eề]n', caseSensitive: false),
    RegExp(r't[oổ]ng\s*ti[eề]n', caseSensitive: false),
    RegExp(r'c[oộ]ng\s*ti[eề]n\s*h[aà]ng', caseSensitive: false),
    RegExp(r'ph[aả]i\s*thanh\s*to[aá]n', caseSensitive: false),
    RegExp(r'thanh\s*to[aá]n', caseSensitive: false),
    RegExp(r'total\s*amount', caseSensitive: false),
    RegExp(r'amount\s*due', caseSensitive: false),
    RegExp(r'net\s*amount', caseSensitive: false),
    RegExp(r'\btotal\b', caseSensitive: false),
  ];

  // Excluded Amount keywords (tenders, change returned, discount, tax ID, phone)
  static final List<RegExp> _excludedAmountKeywords = [
    RegExp(r'ti[eề]n\s*th[oố]i|th[oố]i\s*l[aạ]i|ti[eề]n\s*th[uừ]a|change\s*due', caseSensitive: false),
    RegExp(r'kh[aá]ch\s*đ[uư]a|ti[eề]n\s*m[aặ]t\s*đ[uư]a|cash\s*tendered', caseSensitive: false),
    RegExp(r'gi[aả]m\s*gi[aá]|discount|khuy[eế]n\s*m[aã]i', caseSensitive: false),
    RegExp(r'm[aã]\s*s[oố]\s*thu[eế]|mst|tax\s*id|stt', caseSensitive: false),
    RegExp(r'tel|phone|hotline|b[aà]n\s*s[oố]|qu[aầ]y', caseSensitive: false),
  ];

  /// Core parsing entrypoint: analyzes raw OCR text and line bounding data
  static OcrScanResult parse(String rawText, {List<OcrBoundingElement> boundingElements = const []}) {
    if (rawText.trim().isEmpty) {
      return OcrScanResult(
        rawText: '',
        lines: const [],
        detectedCategory: ExpenseCategory.fromId('other'),
      );
    }

    final rawLines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract Merchant Name
    final merchantResult = _extractMerchant(rawLines);

    // 2. Extract Total Monetary Amount & Currency
    final totalResult = _extractTotalAmount(rawLines);

    // 3. Extract Date and Time
    final dateResult = _extractDate(rawLines);

    // 4. Infer Category based on Merchant override or context keyword matching
    ExpenseCategory detectedCat = ExpenseCategory.fromId('other');
    if (merchantResult.value != null) {
      final merchantLower = merchantResult.value!.toLowerCase();
      for (final entry in _merchantCategoryOverrides.entries) {
        if (merchantLower.contains(entry.key)) {
          detectedCat = ExpenseCategory.fromId(entry.value);
          break;
        }
      }
    }
    if (detectedCat.id == 'other') {
      final combinedContext = '${merchantResult.value ?? ""} $rawText';
      detectedCat = ExpenseCategory.detectFromText(combinedContext);
    }

    // 5. Extract itemized rows
    final items = _extractLineItems(rawLines);

    // Confidence metrics
    final confidenceScores = <String, double>{
      'merchant': merchantResult.confidence,
      'total': totalResult.confidence,
      'date': dateResult.confidence,
    };

    return OcrScanResult(
      rawText: rawText,
      lines: rawLines,
      boundingElements: boundingElements,
      extractedMerchant: merchantResult.value,
      extractedTotal: totalResult.value,
      extractedCurrency: totalResult.currency,
      extractedDate: dateResult.value,
      detectedCategory: detectedCat,
      extractedItems: items,
      confidenceScores: confidenceScores,
    );
  }

  /// Heuristic merchant identification
  static _ExtractionResult<String> _extractMerchant(List<String> lines) {
    if (lines.isEmpty) return _ExtractionResult(null, 0.0);

    // Pass A: Check known popular brands in top 10 lines
    for (int i = 0; i < math.min(10, lines.length); i++) {
      final line = lines[i];
      for (final brand in _knownMerchants) {
        if (line.toLowerCase().contains(brand.toLowerCase())) {
          return _ExtractionResult(brand, 0.95);
        }
      }
    }

    // Pass B: First valid non-noise line in top 5 lines
    for (int i = 0; i < math.min(5, lines.length); i++) {
      final line = lines[i];
      if (line.length < 3 || line.length > 50) continue;

      // Discard pure numeric or date lines
      if (RegExp(r'^[0-9\s\.\,\-\/\:]+$').hasMatch(line)) continue;

      // Check if matches known noise
      bool isNoise = false;
      for (final pattern in _merchantNoisePatterns) {
        if (pattern.hasMatch(line)) {
          isNoise = true;
          break;
        }
      }
      if (isNoise) continue;

      // Clean up punctuation prefix
      final cleaned = line.replaceAll(RegExp(r'^[#*=\-_:\s]+'), '').trim();
      if (cleaned.isNotEmpty) {
        return _ExtractionResult(cleaned, 0.75);
      }
    }

    // Fallback: Use the very first non-empty line
    return _ExtractionResult(lines.first, 0.40);
  }

  /// Heuristic monetary extraction
  static _AmountResult _extractTotalAmount(List<String> lines) {
    double? bestAmount;
    String currency = 'VND';
    double confidence = 0.0;

    // Pattern priorities:
    // 1. Grouped thousands: 150.000, 150,000, 1.250.000, with optional decimal .00
    // 2. Decimals: 10.53, 5.50
    // 3. Shorthand: 45k, 150K
    // 4. Raw integers: 150000, 25000
    final moneyPattern = RegExp(
      r'(?:[\$đ₫]?\s*)(\d{1,3}(?:[\.,]\d{3})+(?:[\.,]\d{2})?|\d+(?:\.\d{1,2})|\d+(?:k|K)?)\s*(?:đ|₫|VND|vnd|vnđ|USD|\$)?',
      caseSensitive: false,
    );

    // Pass A: Scan lines matching high-confidence keywords (grand total, tổng cộng, thanh toán...)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for exclusion (cash tendered, change, etc.)
      bool isExcluded = false;
      for (final excl in _excludedAmountKeywords) {
        if (excl.hasMatch(line)) {
          isExcluded = true;
          break;
        }
      }
      if (isExcluded) continue;

      for (final kw in _totalKeywords) {
        if (kw.hasMatch(line)) {
          final candidates = [line];
          if (i + 1 < lines.length) candidates.add(lines[i + 1]);

          for (final cand in candidates) {
            final matches = moneyPattern.allMatches(cand);
            for (final m in matches) {
              final rawVal = m.group(1);
              if (rawVal != null) {
                final parsed = _parseCleanNumber(rawVal);
                if (parsed != null && _isValidExpenseAmount(parsed)) {
                  bestAmount = parsed;
                  currency = (cand.contains(r'$') || cand.toUpperCase().contains('USD') || rawVal.contains(r'$'))
                      ? 'USD'
                      : 'VND';
                  confidence = 0.95;
                  return _AmountResult(bestAmount, currency, confidence);
                }
              }
            }
          }
        }
      }
    }

    // Pass B: Scan backwards from the bottom half of the receipt
    final startIndex = (lines.length * 0.4).floor();
    for (int i = lines.length - 1; i >= startIndex; i--) {
      final line = lines[i];

      // Discard excluded lines
      bool isExcluded = false;
      for (final excl in _excludedAmountKeywords) {
        if (excl.hasMatch(line)) {
          isExcluded = true;
          break;
        }
      }
      if (isExcluded) continue;

      final matches = moneyPattern.allMatches(line);
      for (final m in matches) {
        final rawVal = m.group(1);
        if (rawVal != null) {
          final parsed = _parseCleanNumber(rawVal);
          if (parsed != null && _isValidExpenseAmount(parsed)) {
            if (parsed >= 1) {
              bestAmount = parsed;
              currency = line.contains(r'$') ? 'USD' : 'VND';
              confidence = 0.70;
              return _AmountResult(bestAmount, currency, confidence);
            }
          }
        }
      }
    }

    // Pass C: Fallback to largest plausible number found in entire receipt
    double maxFound = 0.0;
    for (final line in lines) {
      if (RegExp(r'mst|tel|phone|hotline|s[dđ]t', caseSensitive: false).hasMatch(line)) continue;
      final matches = moneyPattern.allMatches(line);
      for (final m in matches) {
        final rawVal = m.group(1);
        if (rawVal != null) {
          final parsed = _parseCleanNumber(rawVal);
          if (parsed != null && _isValidExpenseAmount(parsed) && parsed > maxFound) {
            maxFound = parsed;
          }
        }
      }
    }

    if (maxFound > 0) {
      return _AmountResult(maxFound, currency, 0.50);
    }

    return _AmountResult(null, currency, 0.0);
  }

  /// Parses sanitized numeric strings (e.g., '150.000', '150,000', '45k', '10.53')
  static double? _parseCleanNumber(String raw) {
    String clean = raw.trim().replaceAll(r'$', '');

    // Check for 'k' / 'K' suffix (e.g. 45k -> 45000)
    if (clean.toLowerCase().endsWith('k')) {
      final base = double.tryParse(clean.substring(0, clean.length - 1).trim());
      if (base != null) return base * 1000.0;
    }

    // Discard phone numbers (09xx, 08xx, 03xx, 07xx with 10 digits)
    if (RegExp(r'^0[35789]\d{8}$').hasMatch(clean.replaceAll(RegExp(r'\D'), ''))) {
      return null;
    }

    // Mixed separator: 1,250,000.50 -> 1250000.50
    if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})$').hasMatch(clean)) {
      clean = clean.replaceAll(',', '');
      return double.tryParse(clean);
    }

    // Mixed separator: 1.250.000,50 -> 1250000.50
    if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d{1,2})$').hasMatch(clean)) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(clean);
    }

    // Standard Vietnamese thousands dot format: 94.000 or 1.250.000 (dots as thousand separator)
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(clean)) {
      clean = clean.replaceAll('.', '');
      return double.tryParse(clean);
    }

    // Standard US thousands comma format: 150,000 or 1,250,000
    if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(clean)) {
      clean = clean.replaceAll(',', '');
      return double.tryParse(clean);
    }

    // Standard Decimal format: 10.53 or 5.50
    if (RegExp(r'^\d+(\.\d{1,2})$').hasMatch(clean)) {
      return double.tryParse(clean);
    }

    // European comma decimal format: 10,53
    if (RegExp(r'^\d+(,\d{1,2})$').hasMatch(clean)) {
      clean = clean.replaceAll(',', '.');
      return double.tryParse(clean);
    }

    // Plain integer
    final plain = double.tryParse(clean);
    return plain;
  }

  /// Bounds check: Filter out unrealistic values or year numbers
  static bool _isValidExpenseAmount(double amount) {
    if (amount <= 0) return false;
    // Don't mistake current year numbers (2024, 2025, 2026) as amount
    if (amount >= 2024 && amount <= 2028) return false;
    // Expense capping: <= 500 million VND or $20,000 USD
    if (amount > 500000000) return false;
    return true;
  }

  /// Heuristic date parser supporting DD/MM/YYYY, YYYY-MM-DD, Vietnamese "Ngày DD tháng MM năm YYYY"
  static _ExtractionResult<DateTime> _extractDate(List<String> lines) {
    // 1. Textual: Ngày 08 tháng 10 năm 2026
    final textDateRegex = RegExp(
      r'ng[aà]y\s*(\d{1,2})\s*th[aá]ng\s*(\d{1,2})\s*n[aă]m\s*(\d{4})',
      caseSensitive: false,
    );

    // 2. Standard numeric dates: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final dmyRegex = RegExp(r'\b(0?[1-9]|[12]\d|3[01])[\/\-\.](0?[1-9]|1[0-2])[\/\-\.](20\d{2}|\d{2})\b');

    // 3. ISO format: YYYY-MM-DD or YYYY/MM/DD
    final ymdRegex = RegExp(r'\b(20\d{2})[\/\-\.](0?[1-9]|1[0-2])[\/\-\.](0?[1-9]|[12]\d|3[01])\b');

    for (final line in lines) {
      // Check textual date
      final textMatch = textDateRegex.firstMatch(line);
      if (textMatch != null) {
        final day = int.parse(textMatch.group(1)!);
        final month = int.parse(textMatch.group(2)!);
        final year = int.parse(textMatch.group(3)!);
        final dt = _validateDate(year, month, day);
        if (dt != null) return _ExtractionResult(dt, 0.95);
      }

      // Check DMY
      final dmyMatch = dmyRegex.firstMatch(line);
      if (dmyMatch != null) {
        final day = int.parse(dmyMatch.group(1)!);
        final month = int.parse(dmyMatch.group(2)!);
        var year = int.parse(dmyMatch.group(3)!);
        if (year < 100) year += 2000;
        final dt = _validateDate(year, month, day);
        if (dt != null) return _ExtractionResult(dt, 0.90);
      }

      // Check YMD
      final ymdMatch = ymdRegex.firstMatch(line);
      if (ymdMatch != null) {
        final year = int.parse(ymdMatch.group(1)!);
        final month = int.parse(ymdMatch.group(2)!);
        final day = int.parse(ymdMatch.group(3)!);
        final dt = _validateDate(year, month, day);
        if (dt != null) return _ExtractionResult(dt, 0.85);
      }
    }

    return _ExtractionResult(null, 0.0);
  }

  static DateTime? _validateDate(int year, int month, int day) {
    if (year < 2000 || year > 2035) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Extracts candidate line items from middle section of receipt
  static List<ReceiptItem> _extractLineItems(List<String> lines) {
    final items = <ReceiptItem>[];
    // Pattern: [Item Description] [Qty (optional)] [Amount]
    final itemPattern = RegExp(
      r'^(.*?)\s+(?:(\d+)\s*[xX*]\s*)?(\d{1,3}(?:[\.,]\d{3})+|\d{4,8}|\d+\.\d{2})\s*(?:đ|₫|VND)?$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (line.length < 5) continue;
      // Skip header & total lines
      if (_totalKeywords.any((k) => k.hasMatch(line))) continue;
      if (_excludedAmountKeywords.any((k) => k.hasMatch(line))) continue;

      final match = itemPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)?.trim();
        final qtyStr = match.group(2);
        final priceStr = match.group(3);

        if (name != null && name.length >= 2 && priceStr != null) {
          final total = _parseCleanNumber(priceStr) ?? 0.0;
          final qty = (qtyStr != null) ? (double.tryParse(qtyStr) ?? 1.0) : 1.0;
          if (total > 0 && total <= 50000000) {
            items.add(ReceiptItem(
              name: name,
              quantity: qty,
              unitPrice: qty > 0 ? (total / qty) : total,
              totalPrice: total,
              rawLine: line,
            ));
          }
        }
      }
    }
    return items;
  }
}

class _ExtractionResult<T> {
  final T? value;
  final double confidence;
  const _ExtractionResult(this.value, this.confidence);
}

class _AmountResult {
  final double? value;
  final String currency;
  final double confidence;
  const _AmountResult(this.value, this.currency, this.confidence);
}
