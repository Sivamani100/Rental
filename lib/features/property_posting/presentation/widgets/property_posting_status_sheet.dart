import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rental/features/settings/presentation/pages/settings_screen.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/utils/image_compressor.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/image_cropper_sheet.dart';
import 'package:rental/features/property_posting/presentation/pages/photo_position_screen.dart';
enum _UploadStatusState { uploading, success, error }

class PropertyPostingStatusSheet extends StatefulWidget {
  final PropertyModel newProperty;
  final List<XFile> selectedImages;
  final List<String> existingImages;
  final bool isEditing;
  final PropertyModel? propertyToEdit;
  final Future<void> Function(PropertyModel)? onSuccess;
  final VoidCallback? onDismissForm;

  const PropertyPostingStatusSheet({
    super.key,
    required this.newProperty,
    required this.selectedImages,
    required this.existingImages,
    required this.isEditing,
    this.propertyToEdit,
    this.onSuccess,
    this.onDismissForm,
  });

  @override
  State<PropertyPostingStatusSheet> createState() => _PropertyPostingStatusSheetState();
}

class _PropertyPostingStatusSheetState extends State<PropertyPostingStatusSheet> {
  _UploadStatusState _statusState = _UploadStatusState.uploading;
  String _statusMessage = 'Preparing property listing...';
  String _errorMessage = '';
  double _progress = 0.01;
  int _countdownSeconds = 5;
  Timer? _progressRampTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startUploadProcess();
  }

  @override
  void dispose() {
    _progressRampTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startUploadProcess() async {
    if (!mounted) return;
    setState(() {
      _statusState = _UploadStatusState.uploading;
      _statusMessage = 'Preparing property details...';
      _progress = 0.01;
      _errorMessage = '';
      _countdownSeconds = 5;
    });

    // Smooth, natural progress count from 1% up to 80% dynamically while upload processes
    _progressRampTimer?.cancel();
    _progressRampTimer = Timer.periodic(const Duration(milliseconds: 65), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_progress < 0.80) {
        setState(() {
          _progress = (_progress + 0.012).clamp(0.01, 0.80);
        });
      }
    });

    try {
      final supabase = Supabase.instance.client;
      List<String> uploadedUrls = List.from(widget.existingImages);

      // Load watermark raw bytes for background isolate
      Uint8List? watermarkRawBytes;
      try {
        final ByteData watermarkData = await rootBundle.load('assets/images/watermark.png');
        watermarkRawBytes = watermarkData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Failed to load watermark: $e');
      }

      int totalImages = widget.selectedImages.length;
      for (int i = 0; i < totalImages; i++) {
        final file = widget.selectedImages[i];
        if (mounted) {
          setState(() {
            _statusMessage = totalImages == 1
                ? 'Compressing & uploading photo...'
                : 'Uploading photo ${i + 1} of $totalImages (Smart 30KB)...';
          });
        }

        final originalBytes = await file.readAsBytes();

        // Off-thread isolate compression
        final result = await ImageCompressor.smartCompress(
          originalBytes,
          watermarkRawBytes: watermarkRawBytes,
        );

        final rawBaseName = file.name.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$rawBaseName.${result.fileExtension}';

        await supabase.storage.from('property_images').uploadBinary(
          fileName,
          result.bytes,
          fileOptions: FileOptions(contentType: result.mimeType),
        );

        final url = supabase.storage.from('property_images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }

      if (mounted) {
        setState(() {
          _statusMessage = widget.isEditing ? 'Updating property in database...' : 'Saving property listing...';
        });
      }

      // Merge URLs
      final propertyJson = widget.newProperty.toJson();
      if (uploadedUrls.isNotEmpty) {
        propertyJson['image_urls'] = uploadedUrls;
      }
      propertyJson['status'] = widget.isEditing ? widget.propertyToEdit!.status : 'pending';

      if (widget.isEditing) {
        await supabase.from('properties').update(propertyJson).eq('id', widget.propertyToEdit!.id!);
      } else {
        await supabase.from('properties').insert(propertyJson);
      }

      // Invalidate property cache and draft cache
      if (!widget.isEditing) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_properties');
        await prefs.remove('cached_properties_ts');
        await prefs.remove('posting_draft_v1');
      }

      _progressRampTimer?.cancel();

      if (mounted) {
        setState(() {
          _statusState = _UploadStatusState.success;
          _progress = 1.0;
          _statusMessage = widget.isEditing ? 'Property updated successfully!' : 'Property submitted successfully!';
          _countdownSeconds = 5;
        });

        // Trigger parent callback (clears draft, notifies parent listeners)
        await widget.onSuccess?.call(widget.newProperty);

        // Start live 5-second countdown timer for full-page success screen
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            if (_countdownSeconds > 1) {
              _countdownSeconds--;
            } else {
              timer.cancel();
              // Dismiss status sheet modal
              Navigator.of(context).pop();
              // Dismiss underlying post form modal to land cleanly on HomeScreen
              widget.onDismissForm?.call();
            }
          });
        });
      }
    } catch (e) {
      _progressRampTimer?.cancel();
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() {
          _statusState = _UploadStatusState.error;
          _errorMessage = e.toString().replaceAll('ClientException: ', '').replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSuccess = _statusState == _UploadStatusState.success;

    return Container(
      height: isSuccess ? screenHeight * 0.48 : screenHeight * 0.46, // Spacious minimal bottom sheet height
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Handle Pill Indicator
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

          // Header Logo & "Uploading" Title Bar
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.black, width: 1.8),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        CupertinoIcons.house_fill,
                        color: Colors.black,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isEditing ? 'Updating' : 'Uploading',
                    style: TextStyle(fontFamily: 'ProximaNova', 
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    _statusState == _UploadStatusState.uploading
                        ? (widget.isEditing ? 'Updating Property...' : 'Uploading Property...')
                        : (_statusState == _UploadStatusState.success ? (widget.isEditing ? 'Update Complete' : 'Upload Complete') : (widget.isEditing ? 'Update Failed' : 'Upload Failed')),
                    style: TextStyle(fontFamily: 'ProximaNova', 
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Body Content based on State
          if (_statusState == _UploadStatusState.uploading) _buildUploadingState(isDark),
          if (_statusState == _UploadStatusState.success) _buildSuccessState(isDark),
          if (_statusState == _UploadStatusState.error) _buildErrorState(isDark),
        ],
      ),
    );
  }

  Widget _buildUploadingState(bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 105px Background Circle Disk with Progress Fill & Distinct Gap Before Progress Line
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.01, end: _progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, child) {
              final int displayPercent = (animValue * 100).clamp(1, 100).toInt();
              return Column(
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF3F4F6),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 105,
                          height: 105,
                          child: CircularProgressIndicator(
                            value: animValue,
                            strokeWidth: 5.0,
                            color: AppTheme.primaryYellow,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        Text(
                          '$displayPercent%',
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32), // Distinct 32px gap between circle disk and progress line

                  // Gradual Horizontal Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 5,
                      width: 220,
                      child: LinearProgressIndicator(
                        value: animValue,
                        color: AppTheme.primaryYellow,
                        backgroundColor: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Status Message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'ProximaNova', 
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.isEditing
                ? 'Please keep the app open while we update your listing.'
                : 'Please keep the app open while we upload your listing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'ProximaNova', 
              fontSize: 11.5,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(bool isDark) {
    final String secondLabel = _countdownSeconds == 1 ? 'second' : 'seconds';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Enriched Solid Emerald Green Circle Badge with White Check Icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.checkmark_alt,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Main Headline
          Text(
            widget.isEditing ? 'Property Updated Successfully!' : 'Property Posted Successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'ProximaNova', 
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Flat Admin Review Notice Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardElevated : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFFDE68A),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your post has been sent to admin for review. Once approved, it will go live in the app (usually takes within 3 hours).',
                    style: TextStyle(fontFamily: 'ProximaNova', 
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF92400E),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Live 5-Second Countdown Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardElevated : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppTheme.primaryYellow,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Redirecting to home page in $_countdownSeconds $secondLabel...',
                  style: TextStyle(fontFamily: 'ProximaNova', 
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Symmetrical Solid Red Circle Badge with White Cross Icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.clear,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.isEditing ? 'Update Failed' : 'Posting Failed',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'ProximaNova', 
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardElevated : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFFCA5A5),
                width: 1.0,
              ),
            ),
            child: Text(
              _errorMessage.isNotEmpty ? _errorMessage : (widget.isEditing ? 'Unable to update property. Check connection.' : 'Unable to upload property. Check connection.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'ProximaNova', 
                fontSize: 12.5,
                color: isDark ? Colors.red.shade300 : const Color(0xFF991B1B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Actions: Go Back to Form OR Retry
          Row(
            children: [
              Expanded(
                child: BouncingButton(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardElevated : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Back to Form',
                      style: TextStyle(fontFamily: 'ProximaNova', 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BouncingButton(
                  onTap: _startUploadProcess,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryYellow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Retry Upload',
                      style: TextStyle(fontFamily: 'ProximaNova', 
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}