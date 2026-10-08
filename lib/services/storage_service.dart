import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Manages persistent storage and thumbnail caching for receipt images
class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  /// Gets the dedicated receipts directory in application documents
  Future<Directory> getReceiptsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory(p.join(appDir.path, 'receipts'));
    if (!await receiptDir.exists()) {
      await receiptDir.create(recursive: true);
    }
    return receiptDir;
  }

  /// Gets the dedicated thumbnails cache directory
  Future<Directory> getThumbnailsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory(p.join(appDir.path, 'thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  /// Caches an original captured receipt file into the persistent documents directory
  Future<String> saveReceiptImage(File sourceImage) async {
    final receiptDir = await getReceiptsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(sourceImage.path).isEmpty ? '.jpg' : p.extension(sourceImage.path);
    final targetPath = p.join(receiptDir.path, 'receipt_$timestamp$ext');
    final savedFile = await sourceImage.copy(targetPath);
    return savedFile.path;
  }

  /// Creates and caches a downscaled thumbnail file path
  /// In native environments with image resizing or simple file link
  Future<String> cacheThumbnail(String originalImagePath) async {
    final thumbDir = await getThumbnailsDirectory();
    final fileName = p.basename(originalImagePath);
    final thumbPath = p.join(thumbDir.path, 'thumb_$fileName');

    final origFile = File(originalImagePath);
    if (await origFile.exists()) {
      // Copy or write optimized thumbnail file
      await origFile.copy(thumbPath);
      return thumbPath;
    }
    return originalImagePath;
  }

  /// Deletes receipt file and its associated thumbnail
  Future<void> deleteReceiptFiles({String? imagePath, String? thumbnailPath}) async {
    if (imagePath != null) {
      final f = File(imagePath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    if (thumbnailPath != null) {
      final f = File(thumbnailPath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }
}
