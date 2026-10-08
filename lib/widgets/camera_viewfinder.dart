import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

/// Camera Viewfinder with Framing Crop Overlay, Flash Toggle, and Tap-to-Focus
class CameraViewfinder extends StatefulWidget {
  final Function(String imagePath) onImageCaptured;
  final Function(String sampleRawText) onSampleSelected;

  const CameraViewfinder({
    super.key,
    required this.onImageCaptured,
    required this.onSampleSelected,
  });

  @override
  State<CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<CameraViewfinder> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusPoint;
  late AnimationController _focusAnimController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        final backCamera = _availableCameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _availableCameras.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Camera initialization error (using simulated viewfinder): $e');
    }
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    final nextMode = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.torch,
      FlashMode.torch => FlashMode.off,
      _ => FlashMode.off,
    };

    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (_) {}
  }

  Future<void> _onTapToFocus(TapUpDetails details, BoxConstraints constraints) async {
    final offset = details.localPosition;
    setState(() {
      _focusPoint = offset;
    });

    _focusAnimController.forward(from: 0.0);

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      final x = offset.dx / constraints.maxWidth;
      final y = offset.dy / constraints.maxHeight;
      try {
        await _cameraController!.setFocusPoint(Offset(x, y));
        await _cameraController!.setExposurePoint(Offset(x, y));
      } catch (_) {}
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final image = await _cameraController!.takePicture();
        widget.onImageCaptured(image.path);
        return;
      } catch (e) {
        print('Capture error: $e');
      }
    }

    // Fallback: pick sample receipt
    _showSamplePickerSheet();
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        widget.onImageCaptured(image.path);
      }
    } catch (e) {
      print('Gallery picker error: $e');
    }
  }

  void _showSamplePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Sample Receipt for Demo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.coffee, color: Colors.brown),
                  title: const Text('Highlands Coffee (Food)'),
                  subtitle: const Text('94.000 ₫ • 08/10/2026'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSampleSelected('''
HIGHLANDS COFFEE
Đ/c: 135 Hai Bà Trưng, Q.1, TP.HCM
Ngày: 08/10/2026 14:15
Số HĐ: HD-88492
1 Phin Sữa Đá L 39.000
1 Trà Sen Vàng L 55.000
Cộng tiền hàng: 94.000
TỔNG CỘNG: 94.000 đ
Tiền khách đưa: 100.000
Tiền thối lại: 6.000
''');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Colors.green),
                  title: const Text('Circle K Minimart (Groceries)'),
                  subtitle: const Text('25.000 ₫ • 08/10/2026'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSampleSelected('''
CIRCLE K VIETNAM
MST: 0305882190
HD: CK-88291
08-10-2026 13:45
Bánh mì que 15.000
Nước suối Aquafina 10.000
Tổng tiền: 25.000 VND
Khách đưa: 50.000
Thối lại: 25.000
''');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book, color: Colors.blue),
                  title: const Text('Nhà Sách Fahasa (Study)'),
                  subtitle: const Text('177.000 ₫ • 15/09/2026'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSampleSelected('''
NHÀ SÁCH FAHASA
Chi nhánh Tân Định
Ngày 15/09/2026
Vở kẻ ngang 5 quyển 45.000
Bút bi Thiên Long 2 cây 12.000
Sách Giáo trình Flutter 120.000
THANH TOÁN: 177,000 đ
''');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_taxi, color: Colors.amber),
                  title: const Text('GrabCar Ride (Travel)'),
                  subtitle: const Text('78.000 ₫ • 01/10/2026'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSampleSelected('''
GRAB VIETNAM
Chuyến đi GrabCar
Ngày 01/10/2026 18:30
Cước phí: 68.000 VND
Phí cầu đường: 10.000
Tổng thanh toán: 78.000 đ
''');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Camera Preview or Simulated Viewfinder
            if (_isCameraInitialized && _cameraController != null)
              GestureDetector(
                onTapUp: (details) => _onTapToFocus(details, constraints),
                child: CameraPreview(_cameraController!),
              )
            else
              GestureDetector(
                onTapUp: (details) => _onTapToFocus(details, constraints),
                child: Container(
                  color: const Color(0xFF111827),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 72, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Align Receipt Inside Frame',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Framing Crop Overlay (CustomPainter)
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _FramingOverlayPainter(),
            ),

            // 3. Focus Tap Indicator Box
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 32,
                top: _focusPoint!.dy - 32,
                child: AnimatedBuilder(
                  animation: _focusAnimController,
                  builder: (context, child) {
                    final scale = 1.0 - _focusAnimController.value * 0.25;
                    final opacity = (1.0 - _focusAnimController.value).clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 4. Top Controls: Flash, Preset, Close
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.center_focus_strong, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Auto-Detect Active',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          switch (_flashMode) {
                            FlashMode.off => Icons.flash_off,
                            FlashMode.auto => Icons.flash_auto,
                            FlashMode.torch => Icons.flash_on,
                            _ => Icons.flash_off,
                          },
                          color: _flashMode == FlashMode.torch ? Colors.amber : Colors.white,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Bottom Capture Controls
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery Picker
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
                        onPressed: _pickFromGallery,
                        tooltip: 'Import from Gallery',
                      ),

                      // Shutter Capture Button
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.camera_alt, color: Colors.blueAccent, size: 36),
                            ),
                          ),
                        ),
                      ),

                      // Preset Samples Picker
                      IconButton(
                        icon: const Icon(Icons.receipt, color: Colors.amber, size: 32),
                        onPressed: _showSamplePickerSheet,
                        tooltip: 'Load Sample Receipt',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// CustomPainter drawing the darkened framing overlay with corner brackets
class _FramingOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const horizontalMargin = 28.0;
    const verticalMargin = 100.0;
    final frameRect = Rect.fromLTWH(
      horizontalMargin,
      verticalMargin,
      size.width - horizontalMargin * 2,
      size.height - verticalMargin * 2 - 80,
    );

    // 1. Darkened translucent vignette outside receipt frame
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final framePath = Path()..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(16)));
    final cutoutPath = Path.combine(PathOperation.difference, backgroundPath, framePath);

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawPath(cutoutPath, bgPaint);

    // 2. High-contrast Targeting Corner Brackets (L-brackets)
    final cornerPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-Left
    canvas.drawLine(Offset(frameRect.left, frameRect.top + cornerLen), Offset(frameRect.left, frameRect.top), cornerPaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.top), Offset(frameRect.left + cornerLen, frameRect.top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(frameRect.right - cornerLen, frameRect.top), Offset(frameRect.right, frameRect.top), cornerPaint);
    canvas.drawLine(Offset(frameRect.right, frameRect.top), Offset(frameRect.right, frameRect.top + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(frameRect.left, frameRect.bottom - cornerLen), Offset(frameRect.left, frameRect.bottom), cornerPaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.bottom), Offset(frameRect.left + cornerLen, frameRect.bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(frameRect.right - cornerLen, frameRect.bottom), Offset(frameRect.right, frameRect.bottom), cornerPaint);
    canvas.drawLine(Offset(frameRect.right, frameRect.bottom), Offset(frameRect.right, frameRect.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
