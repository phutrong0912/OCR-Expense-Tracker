import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import '../services/regex_parser.dart';
import '../widgets/camera_viewfinder.dart';
import 'review_verification_screen.dart';

/// Receipt Scanner Screen hosting camera viewfinder and OCR processing pipeline
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;
  String _processingMessage = 'Extracting receipt text via Google ML Kit...';

  Future<void> _handleImageCaptured(String imagePath) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'On-Device ML Kit OCR Scanning...\nSub-100ms Heuristic Extraction';
    });

    try {
      final scanResult = await OcrService.instance.extractFromImageFile(imagePath);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewVerificationScreen(
              scanResult: scanResult,
              imagePath: imagePath,
            ),
          ),
        );

        if (saved == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting OCR: $e')),
        );
      }
    }
  }

  void _handleSampleSelected(String rawText) {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Running Regex Heuristic Engine...';
    });

    Future.delayed(const Duration(milliseconds: 150), () async {
      final scanResult = ReceiptRegexParser.parse(rawText);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewVerificationScreen(
              scanResult: scanResult,
            ),
          ),
        );

        if (saved == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraViewfinder(
            onImageCaptured: _handleImageCaptured,
            onSampleSelected: _handleSampleSelected,
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.blueAccent),
                      const SizedBox(height: 16),
                      Text(
                        _processingMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

