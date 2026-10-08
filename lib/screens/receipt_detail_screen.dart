import 'dart:io';
import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../database/db_helper.dart';
import '../services/storage_service.dart';

/// Receipt Detail Screen with itemized breakdown and raw OCR transcript view
class ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onReceiptUpdated;

  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    required this.onReceiptUpdated,
  });

  Future<void> _deleteReceipt(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Receipt Record?'),
        content: Text('Are you sure you want to permanently delete receipt for ${receipt.merchant}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && receipt.id != null) {
      await DatabaseHelper.instance.deleteReceipt(receipt.id!);
      await StorageService.instance.deleteReceiptFiles(
        imagePath: receipt.imagePath,
        thumbnailPath: receipt.thumbnailPath,
      );
      onReceiptUpdated();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt record deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = receipt.category;

    return Scaffold(
      appBar: AppBar(
        title: Text(receipt.merchant),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deleteReceipt(context),
            tooltip: 'Delete Receipt',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Receipt Header Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(cat.colorHex).withOpacity(0.15),
                    child: Icon(
                      IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                      size: 28,
                      color: Color(cat.colorHex),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    receipt.merchant,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(cat.colorHex).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(cat.colorHex),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    receipt.formattedAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transaction Date: ${receipt.formattedDateTime}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Receipt Image Thumbnail / Full View
          if (receipt.imagePath != null && File(receipt.imagePath!).existsSync())
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Receipt Photo (Cached)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        color: Colors.black12,
                        child: InteractiveViewer(
                          child: Image.file(
                            File(receipt.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Itemized Breakdown
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                      const Text('Itemized Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${receipt.items.length} items', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 20),
                  if (receipt.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No itemized breakdown entered for this transaction.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...receipt.items.map((it) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    'Qty: ${it.quantity.toInt()} x ${it.unitPrice.round()}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${it.totalPrice.round()} ${receipt.currency == "VND" ? "₫" : r"$"}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          if (receipt.notes != null && receipt.notes!.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(receipt.notes!, style: TextStyle(color: Colors.grey.shade800)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Raw OCR Transcript Collapsible Panel
          if (receipt.rawOcrText != null && receipt.rawOcrText!.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ExpansionTile(
                title: const Text('Raw OCR Audit Transcript', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('Inspect original text recognized from camera', style: TextStyle(fontSize: 12)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      receipt.rawOcrText!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
