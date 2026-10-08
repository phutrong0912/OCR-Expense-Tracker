import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/category.dart';

/// Aggregation model for category distribution
class CategorySpending {
  final ExpenseCategory category;
  final double totalAmount;
  final int count;
  final double percentage;

  const CategorySpending({
    required this.category,
    required this.totalAmount,
    required this.count,
    required this.percentage,
  });
}

/// Day aggregate model for weekly bar chart
class DailySpending {
  final DateTime date;
  final double totalAmount;
  final String dayName;

  const DailySpending({
    required this.date,
    required this.totalAmount,
    required this.dayName,
  });
}

/// SQLite Database Helper for Receipt persistence & Transaction Lifecycle
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Fallback in-memory cache for test/web environments
  final List<Receipt> _inMemoryReceipts = [];
  bool _useInMemory = false;
  int _nextInMemoryId = 1;

  DatabaseHelper._init();

  void enableInMemoryMode() {
    _useInMemory = true;
  }

  Future<Database?> get database async {
    if (_useInMemory) return null;
    if (_database != null) return _database!;
    try {
      _database = await _initDB('receipt_tracker.db');
      return _database!;
    } catch (e) {
      // In non-native environments (e.g. tests), fall back to in-memory seamlessly
      _useInMemory = true;
      return null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        total_amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'VND',
        date TEXT NOT NULL,
        category_id TEXT NOT NULL,
        image_path TEXT,
        thumbnail_path TEXT,
        raw_ocr_text TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receipt_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_price REAL NOT NULL DEFAULT 0.0,
        total_price REAL NOT NULL,
        raw_line TEXT,
        FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_receipts_date ON receipts (date)');
    await db.execute('CREATE INDEX idx_receipts_category ON receipts (category_id)');
  }

  /// Insert a receipt and its associated itemized lines atomically
  Future<int> insertReceipt(Receipt receipt) async {
    final db = await database;
    if (db == null || _useInMemory) {
      final newId = _nextInMemoryId++;
      final savedItems = receipt.items
          .map((it) => it.copyWith(receiptId: newId))
          .toList();
      final savedReceipt = receipt.copyWith(id: newId, items: savedItems);
      _inMemoryReceipts.add(savedReceipt);
      return newId;
    }

    return await db.transaction((txn) async {
      final receiptId = await txn.insert('receipts', receipt.toMap());
      for (final item in receipt.items) {
        final itemMap = item.toMap();
        itemMap['receipt_id'] = receiptId;
        await txn.insert('receipt_items', itemMap);
      }
      return receiptId;
    });
  }

  /// Update an existing receipt and sync items
  Future<int> updateReceipt(Receipt receipt) async {
    final db = await database;
    if (db == null || _useInMemory) {
      final index = _inMemoryReceipts.indexWhere((r) => r.id == receipt.id);
      if (index != -1) {
        _inMemoryReceipts[index] = receipt;
        return 1;
      }
      return 0;
    }

    return await db.transaction((txn) async {
      final count = await txn.update(
        'receipts',
        receipt.toMap(),
        where: 'id = ?',
        whereArgs: [receipt.id],
      );

      // Replace items
      await txn.delete(
        'receipt_items',
        where: 'receipt_id = ?',
        whereArgs: [receipt.id],
      );

      for (final item in receipt.items) {
        final itemMap = item.toMap();
        itemMap['receipt_id'] = receipt.id;
        await txn.insert('receipt_items', itemMap);
      }

      return count;
    });
  }

  /// Delete a receipt by ID
  Future<int> deleteReceipt(int id) async {
    final db = await database;
    if (db == null || _useInMemory) {
      final initialCount = _inMemoryReceipts.length;
      _inMemoryReceipts.removeWhere((r) => r.id == id);
      return initialCount - _inMemoryReceipts.length;
    }

    return await db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Retrieve receipt by ID with all line items
  Future<Receipt?> getReceiptById(int id) async {
    final db = await database;
    if (db == null || _useInMemory) {
      try {
        return _inMemoryReceipts.firstWhere((r) => r.id == id);
      } catch (_) {
        return null;
      }
    }

    final maps = await db.query(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final itemMaps = await db.query(
      'receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [id],
    );

    final items = itemMaps.map((m) => ReceiptItem.fromMap(m)).toList();
    return Receipt.fromMap(maps.first, items: items);
  }

  /// Query all receipts with optional filters
  Future<List<Receipt>> getAllReceipts({
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await database;
    if (db == null || _useInMemory) {
      var result = List<Receipt>.from(_inMemoryReceipts);
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        result = result.where((r) => r.categoryId == categoryId).toList();
      }
      if (startDate != null) {
        result = result.where((r) => r.date.isAfter(startDate.subtract(const Duration(seconds: 1)))).toList();
      }
      if (endDate != null) {
        result = result.where((r) => r.date.isBefore(endDate.add(const Duration(seconds: 1)))).toList();
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        result = result.where((r) =>
            r.merchant.toLowerCase().contains(q) ||
            (r.notes?.toLowerCase().contains(q) ?? false)).toList();
      }
      result.sort((a, b) => b.date.compareTo(a.date));
      return result;
    }

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      whereClauses.add('category_id = ?');
      whereArgs.add(categoryId);
    }

    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(merchant LIKE ? OR notes LIKE ?)');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final receiptMaps = await db.query(
      'receipts',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, id DESC',
    );

    final receipts = <Receipt>[];
    for (final map in receiptMaps) {
      final id = map['id'] as int;
      final itemMaps = await db.query(
        'receipt_items',
        where: 'receipt_id = ?',
        whereArgs: [id],
      );
      final items = itemMaps.map((m) => ReceiptItem.fromMap(m)).toList();
      receipts.add(Receipt.fromMap(map, items: items));
    }

    return receipts;
  }

  /// Calculates spending breakdown by category for the Donut Chart
  Future<List<CategorySpending>> getCategorySpendingSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final receipts = await getAllReceipts(startDate: startDate, endDate: endDate);
    if (receipts.isEmpty) return [];

    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};
    double grandTotal = 0.0;

    for (final r in receipts) {
      categoryTotals[r.categoryId] = (categoryTotals[r.categoryId] ?? 0.0) + r.totalAmount;
      categoryCounts[r.categoryId] = (categoryCounts[r.categoryId] ?? 0) + 1;
      grandTotal += r.totalAmount;
    }

    final results = <CategorySpending>[];
    categoryTotals.forEach((catId, total) {
      final category = ExpenseCategory.fromId(catId);
      final count = categoryCounts[catId] ?? 0;
      final percentage = grandTotal > 0 ? (total / grandTotal) * 100 : 0.0;
      results.add(CategorySpending(
        category: category,
        totalAmount: total,
        count: count,
        percentage: percentage,
      ));
    });

    results.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return results;
  }

  /// Aggregates daily spending for the past 7 days for the Weekly Bar Chart
  Future<List<DailySpending>> getWeeklySpendingSummary() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DailySpending>[];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 6; i >= 0; i--) {
      final targetDate = today.subtract(Duration(days: i));
      final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
      final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final receipts = await getAllReceipts(startDate: dayStart, endDate: dayEnd);
      final total = receipts.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
      final dayName = dayNames[targetDate.weekday - 1];

      days.add(DailySpending(
        date: targetDate,
        totalAmount: total,
        dayName: dayName,
      ));
    }

    return days;
  }

  /// Seed initial demo data for realistic user experience
  Future<void> seedInitialData() async {
    final existing = await getAllReceipts();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();

    final samples = [
      Receipt(
        merchant: 'Highlands Coffee',
        totalAmount: 94000,
        currency: 'VND',
        date: now.subtract(const Duration(hours: 4)),
        categoryId: 'food',
        notes: 'Phin Sữa Đá + Trà Sen Vàng with friends',
        items: const [
          ReceiptItem(name: 'Phin Sữa Đá L', quantity: 1, unitPrice: 39000, totalPrice: 39000),
          ReceiptItem(name: 'Trà Sen Vàng L', quantity: 1, unitPrice: 55000, totalPrice: 55000),
        ],
      ),
      Receipt(
        merchant: 'Circle K',
        totalAmount: 42000,
        currency: 'VND',
        date: now.subtract(const Duration(days: 1, hours: 2)),
        categoryId: 'groceries',
        notes: 'Quick snack & bottle of water',
        items: const [
          ReceiptItem(name: 'Bánh mì que Pate', quantity: 2, unitPrice: 16000, totalPrice: 32000),
          ReceiptItem(name: 'Nước suối Dasani 500ml', quantity: 1, unitPrice: 10000, totalPrice: 10000),
        ],
      ),
      Receipt(
        merchant: 'Fahasa Bookstore',
        totalAmount: 185000,
        currency: 'VND',
        date: now.subtract(const Duration(days: 2, hours: 5)),
        categoryId: 'study',
        notes: 'Stationery & Study Notebooks',
        items: const [
          ReceiptItem(name: 'Tập vở Campus 200T', quantity: 3, unitPrice: 25000, totalPrice: 75000),
          ReceiptItem(name: 'Bút Gel Pentel EnerGel', quantity: 2, unitPrice: 35000, totalPrice: 70000),
          ReceiptItem(name: 'Bút dạ quang Stabilo', quantity: 2, unitPrice: 20000, totalPrice: 40000),
        ],
      ),
      Receipt(
        merchant: 'GrabCar',
        totalAmount: 78000,
        currency: 'VND',
        date: now.subtract(const Duration(days: 3, hours: 8)),
        categoryId: 'travel',
        notes: 'Campus ride during heavy rain',
        items: const [
          ReceiptItem(name: 'GrabCar ride', quantity: 1, unitPrice: 78000, totalPrice: 78000),
        ],
      ),
      Receipt(
        merchant: 'CGV Cinemas',
        totalAmount: 220000,
        currency: 'VND',
        date: now.subtract(const Duration(days: 4, hours: 1)),
        categoryId: 'entertainment',
        notes: 'Weekend movie ticket for club outing',
        items: const [
          ReceiptItem(name: '2D Movie Ticket (Student)', quantity: 2, unitPrice: 85000, totalPrice: 170000),
          ReceiptItem(name: 'Sweet Popcorn Combo', quantity: 1, unitPrice: 50000, totalPrice: 50000),
        ],
      ),
      Receipt(
        merchant: 'Thế Giới Di Động',
        totalAmount: 250000,
        currency: 'VND',
        date: now.subtract(const Duration(days: 5, hours: 6)),
        categoryId: 'gear',
        notes: 'Type-C Fast Charging Cable & Adapter',
        items: const [
          ReceiptItem(name: 'Cáp sạc Type-C Baseus 65W', quantity: 1, unitPrice: 250000, totalPrice: 250000),
        ],
      ),
      Receipt(
        merchant: 'Cơm Tấm Ba Ghiền',
        totalAmount: 75000,
        currency: 'VND',
        date: now.subtract(const Duration(days: 6, hours: 3)),
        categoryId: 'food',
        notes: 'Lunch after midterm exam',
        items: const [
          ReceiptItem(name: 'Cơm tấm sườn bì chả', quantity: 1, unitPrice: 70000, totalPrice: 70000),
          ReceiptItem(name: 'Trà đá', quantity: 1, unitPrice: 5000, totalPrice: 5000),
        ],
      ),
    ];

    for (final sample in samples) {
      await insertReceipt(sample);
    }
  }
}

