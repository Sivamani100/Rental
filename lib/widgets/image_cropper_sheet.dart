import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';

enum CropAspectRatio {
  ratio16x9(16 / 9, '16:9 Cover'),
  ratio4x3(4 / 3, '4:3 Card'),
  ratio1x1(1 / 1, '1:1 Square'),
  free(0, 'Free Ratio');

  final double ratio;
  final String label;
  const CropAspectRatio(this.ratio, this.label);
}

class ImageCropperSheet {
  /// Opens the best cropper for the environment.
  /// Tries native uCrop on mobile devices; falls back to in-app Flutter cropper on Web or if native cropper is unavailable.
  static Future<XFile?> open(BuildContext context, XFile imageFile) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Try native image_cropper on all platforms (Mobile/Web)
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Adjust Photo',
            toolbarColor: isDark ? const Color(0xFF18181C) : Colors.black,
            toolbarWidgetColor: isDark ? AppTheme.primaryYellow : Colors.white,
            activeControlsWidgetColor: AppTheme.primaryYellow,
            backgroundColor: isDark ? const Color(0xFF101014) : Colors.black,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            showCropGrid: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop & Adjust Photo',
            aspectRatioPickerButtonHidden: false,
            resetAspectRatioEnabled: true,
            aspectRatioLockEnabled: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
          ),
        ],
      );

      if (croppedFile != null) {
        return XFile(croppedFile.path);
      } else {
        // User cancelled native cropper
        return null;
      }
    } catch (e) {
      debugPrint('Native cropper exception, falling back to in-app cropper: $e');
    }

    if (!context.mounted) return null;

    // 2. Fallback / Web In-App Interactive Cropper Sheet
    return await showModalBottomSheet<XFile?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InAppInteractiveCropperModal(imageFile: imageFile),
    );
  }
}

class _InAppInteractiveCropperModal extends StatefulWidget {
  final XFile imageFile;
  const _InAppInteractiveCropperModal({required this.imageFile});

  @override
  State<_InAppInteractiveCropperModal> createState() => _InAppInteractiveCropperModalState();
}

class _InAppInteractiveCropperModalState extends State<_InAppInteractiveCropperModal> {
  Uint8List? _imageBytes;
  int _origWidth = 0;
  int _origHeight = 0;
  int _rotationDegrees = 0;
  CropAspectRatio _selectedRatio = CropAspectRatio.ratio16x9;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && mounted) {
        setState(() {
          _imageBytes = bytes;
          _origWidth = decoded.width;
          _origHeight = decoded.height;
        });
      }
    } catch (e) {
      debugPrint('Error loading image bytes: $e');
    }
  }

  void _rotateRight() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
  }

  Future<void> _applyCropAndSave() async {
    if (_imageBytes == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      img.Image? decoded = img.decodeImage(_imageBytes!);
      if (decoded == null) throw Exception('Could not decode image');

      // Apply 90/180/270 rotation
      if (_rotationDegrees != 0) {
        if (_rotationDegrees == 90) {
          decoded = img.copyRotate(decoded, angle: 90);
        } else if (_rotationDegrees == 180) {
          decoded = img.copyRotate(decoded, angle: 180);
        } else if (_rotationDegrees == 270) {
          decoded = img.copyRotate(decoded, angle: 270);
        }
      }

      // Apply aspect ratio cropping
      if (_selectedRatio != CropAspectRatio.free && _selectedRatio.ratio > 0) {
        final double targetRatio = _selectedRatio.ratio;
        final double currentRatio = decoded.width / decoded.height;

        int cropW = decoded.width;
        int cropH = decoded.height;
        int cropX = 0;
        int cropY = 0;

        if (currentRatio > targetRatio) {
          // Image is wider than target ratio -> crop width
          cropW = (decoded.height * targetRatio).round().clamp(1, decoded.width);
          cropX = ((decoded.width - cropW) / 2).round();
        } else if (currentRatio < targetRatio) {
          // Image is taller than target ratio -> crop height
          cropH = (decoded.width / targetRatio).round().clamp(1, decoded.height);
          cropY = ((decoded.height - cropH) / 2).round();
        }

        decoded = img.copyCrop(
          decoded,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );
      }

      final croppedJpg = img.encodeJpg(decoded, quality: 88);

      final croppedXFile = XFile.fromData(
        Uint8List.fromList(croppedJpg),
        mimeType: 'image/jpeg',
        name: 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (mounted) {
        Navigator.pop(context, croppedXFile);
      }
    } catch (e) {
      debugPrint('Error in _applyCropAndSave: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.crop, color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crop & Position Photo',
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (_origWidth > 0)
                          Text(
                            '$_origWidth × $_origHeight px',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Preview Canvas
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth - 32;
                  final maxH = constraints.maxHeight - 32;
                  if (maxW <= 0 || maxH <= 0) return const SizedBox();

                  double targetRatio = _selectedRatio.ratio > 0
                      ? _selectedRatio.ratio
                      : (_origWidth > 0 ? _origWidth / _origHeight : 16 / 9);

                  if ((_rotationDegrees / 90).round() % 2 != 0 && _origWidth > 0) {
                    targetRatio = 1 / targetRatio;
                  }

                  double frameW = maxW;
                  double frameH = frameW / targetRatio;

                  if (frameH > maxH) {
                    frameH = maxH;
                    frameW = frameH * targetRatio;
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_imageBytes != null)
                        SizedBox(
                          width: frameW,
                          height: frameH,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RotatedBox(
                                quarterTurns: (_rotationDegrees / 90).round(),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),

                              // Dynamic Crop Frame & Rule-of-Thirds Grid
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryYellow,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Vertical 3x3 Grid Lines
                                    Row(
                                      children: [
                                        Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: AppTheme.primaryYellow.withValues(alpha: 0.35)))))),
                                        Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: AppTheme.primaryYellow.withValues(alpha: 0.35)))))),
                                        const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                    // Horizontal 3x3 Grid Lines
                                    Column(
                                      children: [
                                        Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryYellow.withValues(alpha: 0.35)))))),
                                        Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryYellow.withValues(alpha: 0.35)))))),
                                        const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                    // 4 Corner Markers
                                    Positioned(top: -2, left: -2, child: Container(width: 14, height: 14, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primaryYellow, width: 4), left: BorderSide(color: AppTheme.primaryYellow, width: 4))))),
                                    Positioned(top: -2, right: -2, child: Container(width: 14, height: 14, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primaryYellow, width: 4), right: BorderSide(color: AppTheme.primaryYellow, width: 4))))),
                                    Positioned(bottom: -2, left: -2, child: Container(width: 14, height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryYellow, width: 4), left: BorderSide(color: AppTheme.primaryYellow, width: 4))))),
                                    Positioned(bottom: -2, right: -2, child: Container(width: 14, height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryYellow, width: 4), right: BorderSide(color: AppTheme.primaryYellow, width: 4))))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryYellow),
                        ),

                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppTheme.primaryYellow),
                                SizedBox(height: 12),
                                Text(
                                  'Cropping Photo...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Toolbar Actions: Rotation & Ratio Selection Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Rotate Button
                IconButton(
                  tooltip: 'Rotate 90°',
                  icon: const Icon(Icons.rotate_right_rounded, color: AppTheme.primaryYellow, size: 26),
                  onPressed: _rotateRight,
                ),
                const SizedBox(width: 8),

                // Aspect Ratio Selector Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CropAspectRatio.values.map((ratio) {
                        final isSelected = _selectedRatio == ratio;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(ratio.label),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedRatio = ratio);
                            },
                            selectedColor: AppTheme.primaryYellow,
                            backgroundColor: isDark ? const Color(0xFF22242D) : Colors.grey.shade200,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Bottom Action Bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BouncingButton(
                      scaleFactor: 0.96,
                      onTap: _applyCropAndSave,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryYellow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Done & Apply Crop',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
