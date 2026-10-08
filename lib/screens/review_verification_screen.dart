import 'dart:io';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/ocr_scan_result.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../database/db_helper.dart';
import '../services/storage_service.dart';

/// Review & Verification Screen: Allows students to inspect raw OCR bounding values,
/// correct noisy mistakes, and verify transaction details before committing to SQLite.
class ReviewVerificationScreen extends StatefulWidget {
  final OcrScanResult scanResult;
  final String? imagePath;

  const ReviewVerificationScreen({
    super.key,
    required this.scanResult,
    this.imagePath,
  });

  @override
  State<ReviewVerificationScreen> createState() => _ReviewVerificationScreenState();
}

class _ReviewVerificationScreenState extends State<ReviewVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  late String _selectedCurrency;
  late String _selectedCategoryId;
  late List<ReceiptItem> _lineItems;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final res = widget.scanResult;
    _merchantController = TextEditingController(text: res.extractedMerchant ?? '');
    _amountController = TextEditingController(
      text: res.extractedTotal != null
          ? (res.extractedTotal! % 1 == 0
              ? res.extractedTotal!.toInt().toString()
              : res.extractedTotal!.toString())
          : '',
    );
    _notesController = TextEditingController();

    _selectedDate = res.extractedDate ?? DateTime.now();
    _selectedCurrency = res.extractedCurrency;
    _selectedCategoryId = res.detectedCategory.id;
    _lineItems = List.from(res.extractedItems);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          timePicked?.hour ?? _selectedDate.hour,
          timePicked?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense total amount.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? savedImagePath;
      String? thumbnailPath;

      if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
        final imgFile = File(widget.imagePath!);
        if (await imgFile.exists()) {
          savedImagePath = await StorageService.instance.saveReceiptImage(imgFile);
          thumbnailPath = await StorageService.instance.cacheThumbnail(savedImagePath);
        }
      }

      final receipt = Receipt(
        merchant: _merchantController.text.trim().isEmpty
            ? 'Unknown Store'
            : _merchantController.text.trim(),
        totalAmount: amount,
        currency: _selectedCurrency,
        date: _selectedDate,
        categoryId: _selectedCategoryId,
        imagePath: savedImagePath,
        thumbnailPath: thumbnailPath,
        rawOcrText: widget.scanResult.rawText,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: _lineItems,
      );

      final id = await DatabaseHelper.instance.insertReceipt(receipt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Receipt #$id saved to SQLite successfully!'),
              ],
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving to SQLite: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _addLineItem() {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final priceCtrl = TextEditingController();
        final qtyCtrl = TextEditingController(text: '1');

        return AlertDialog(
          title: const Text('Add Itemized Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Price'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                if (name.isNotEmpty && price > 0) {
                  setState(() {
                    _lineItems.add(ReceiptItem(
                      name: name,
                      quantity: qty,
                      unitPrice: qty > 0 ? price / qty : price,
                      totalPrice: price,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Verification'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Verify Fields'),
            Tab(icon: Icon(Icons.troubleshoot), text: 'Raw OCR & Bounding'),
          ],
        ),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Writing transaction to SQLite database...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVerificationForm(),
                _buildRawOcrInspector(),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRecord,
                  icon: const Icon(Icons.save),
                  label: const Text('Confirm & Save to SQLite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Extraction Confidence Indicators
          _buildConfidenceCard(),
          const SizedBox(height: 16),

          // Merchant Name Input
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Merchant / Store Name', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _merchantController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.store),
                      hintText: 'e.g. Highlands Coffee, Circle K',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter merchant name' : null,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      _suggestionChip('Highlands'),
                      _suggestionChip('Circle K'),
                      _suggestionChip('Fahasa'),
                      _suggestionChip('Grab'),
                      _suggestionChip('WinMart'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Total Monetary Amount & Currency
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'VND', label: Text('₫ VND')),
                          ButtonSegment(value: 'USD', label: Text(r'$ USD')),
                        ],
                        selected: {_selectedCurrency},
                        onSelectionChanged: (set) {
                          setState(() {
                            _selectedCurrency = set.first;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        _selectedCurrency == 'VND' ? Icons.monetization_on : Icons.attach_money,
                        color: Colors.blue,
                      ),
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please specify total amount';
                      final numVal = double.tryParse(v.trim().replaceAll(',', ''));
                      if (numVal == null || numVal <= 0) return 'Invalid numeric amount';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Transaction Date & Time
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('Transaction Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year} ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _selectDate,
            ),
          ),
          const SizedBox(height: 12),

          // Category Classification Selector
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expense Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExpenseCategory.predefined.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      return ChoiceChip(
                        selected: isSelected,
                        selectedColor: Color(cat.colorHex).withOpacity(0.2),
                        avatar: Icon(
                          IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                          size: 16,
                          color: Color(cat.colorHex),
                        ),
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected ? Color(cat.colorHex) : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategoryId = cat.id;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Itemized Lines
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Itemized Breakdown (${_lineItems.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _addLineItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  if (_lineItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No individual line items parsed. You can add them manually above.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    Column(
                      children: List.generate(_lineItems.length, (idx) {
                        final item = _lineItems[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          subtitle: Text('Qty: ${item.quantity.toInt()}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.totalPrice.round()} ${_selectedCurrency == "VND" ? "₫" : r"$"}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _lineItems.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Optional Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Treasurer / Student Notes (Optional)',
              hintText: 'e.g. Reimbursable club event refreshment',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard() {
    final conf = widget.scanResult.confidenceScores;
    final overall = widget.scanResult.overallConfidence;

    Color badgeColor = Colors.orange;
    String badgeLabel = 'Medium Confidence';
    if (overall >= 0.85) {
      badgeColor = Colors.green;
      badgeLabel = 'High Confidence';
    } else if (overall < 0.60) {
      badgeColor = Colors.red;
      badgeLabel = 'Manual Inspection Required';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: badgeColor),
              const SizedBox(width: 8),
              Text(
                'OCR Heuristic Status: $badgeLabel',
                style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Store: ${(conf["merchant"] != null ? (conf["merchant"]! * 100).toInt() : 50)}%'),
              Text('Total: ${(conf["total"] != null ? (conf["total"]! * 100).toInt() : 50)}%'),
              Text('Date: ${(conf["date"] != null ? (conf["date"]! * 100).toInt() : 50)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _merchantController.text = label;
        });
      },
    );
  }

  Widget _buildRawOcrInspector() {
    final rawLines = widget.scanResult.lines;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any OCR line below to quickly copy it to Merchant or Total Amount.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rawLines.isEmpty)
          const Center(child: Text('No OCR text detected'))
        else
          ...List.generate(rawLines.length, (idx) {
            final line = rawLines[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey.shade300,
                  child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                ),
                title: Text(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (action) {
                    if (action == 'merchant') {
                      setState(() {
                        _merchantController.text = line;
                        _tabController.animateTo(0);
                      });
                    } else if (action == 'amount') {
                      setState(() {
                        _amountController.text = line.replaceAll(RegExp(r'[^\d\.]'), '');
                        _tabController.animateTo(0);
                      });
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'merchant', child: Text('Use as Merchant Name')),
                    PopupMenuItem(value: 'amount', child: Text('Use as Total Amount')),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
