import 'dart:io';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/receipt.dart';
import '../database/db_helper.dart';
import '../services/storage_service.dart';
import 'receipt_detail_screen.dart';

/// Filterable Receipt History Screen with thumbnail caching and swipe-to-delete
class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    final receipts = await DatabaseHelper.instance.getAllReceipts(
      categoryId: _selectedCategory,
      searchQuery: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _receipts = receipts;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteReceipt(Receipt receipt, int index) async {
    if (receipt.id == null) return;

    final deletedId = receipt.id!;
    await DatabaseHelper.instance.deleteReceipt(deletedId);
    await StorageService.instance.deleteReceiptFiles(
      imagePath: receipt.imagePath,
      thumbnailPath: receipt.thumbnailPath,
    );

    setState(() {
      _receipts.removeAt(index);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted receipt for ${receipt.merchant}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await DatabaseHelper.instance.insertReceipt(receipt);
              _loadReceipts();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReceipts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search merchant or notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _loadReceipts();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
                _loadReceipts();
              },
            ),
          ),

          // Horizontal Category Filter Pills
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildCategoryFilterChip('All Categories', 'all'),
                ...ExpenseCategory.predefined.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildCategoryFilterChip(cat.name, cat.id, color: Color(cat.colorHex)),
                  );
                }),
              ],
            ),
          ),

          // Receipts List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _receipts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategory != 'all'
                                  ? 'No receipts matched your filter'
                                  : 'No receipts recorded yet',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReceipts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _receipts.length,
                          itemBuilder: (context, index) {
                            final receipt = _receipts[index];
                            final cat = receipt.category;

                            return Dismissible(
                              key: Key('receipt_${receipt.id}_$index'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteReceipt(receipt, index),
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReceiptDetailScreen(
                                          receipt: receipt,
                                          onReceiptUpdated: _loadReceipts,
                                        ),
                                      ),
                                    );
                                    _loadReceipts();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        // Cached Thumbnail or Category Icon
                                        _buildThumbnail(receipt, cat),
                                        const SizedBox(width: 14),

                                        // Store Name & Meta
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                receipt.merchant,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Color(cat.colorHex).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      cat.name,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(cat.colorHex),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    receipt.formattedDate,
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Total Price
                                        Text(
                                          receipt.formattedAmount,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label, String id, {Color? color}) {
    final isSelected = _selectedCategory == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedCategory = id;
          });
          _loadReceipts();
        }
      },
    );
  }

  Widget _buildThumbnail(Receipt receipt, ExpenseCategory cat) {
    if (receipt.thumbnailPath != null && File(receipt.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(receipt.thumbnailPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Color(cat.colorHex).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
          color: Color(cat.colorHex),
          size: 24,
        ),
      ),
    );
  }
}
