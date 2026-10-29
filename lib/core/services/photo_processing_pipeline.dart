import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/core/utils/image_compressor.dart';

class StagedPhotoResult {
  final String path;
  final String publicUrl;
  final int compressedSize;

  const StagedPhotoResult({
    required this.path,
    required this.publicUrl,
    required this.compressedSize,
  });
}

/// A background pre-processing & uploading pipeline (WhatsApp/Instagram model).
/// Photos start compressing, watermarking, and uploading the instant the user
/// selects them, so when they tap 'Submit' at the end of the form, all URLs
/// are already ready in memory for a near-instantaneous 0-second submission.
class PhotoProcessingPipeline {
  PhotoProcessingPipeline._();
  static final PhotoProcessingPipeline instance = PhotoProcessingPipeline._();

  // Completed photo cache keyed by file.path (or file.name)
  final Map<String, StagedPhotoResult> _cache = {};

  // In-flight upload futures so duplicate calls don't re-upload
  final Map<String, Future<StagedPhotoResult?>> _inFlight = {};

  // Cached watermark bytes in memory
  Uint8List? _cachedWatermark;

  /// Loads the watermark PNG from assets once and caches it in memory.
  Future<Uint8List?> _getWatermark() async {
    if (_cachedWatermark != null) return _cachedWatermark;
    try {
      final data = await rootBundle.load('assets/images/watermark.png');
      _cachedWatermark = data.buffer.asUint8List();
      return _cachedWatermark;
    } catch (e) {
      debugPrint('[PhotoPipeline] Failed to load watermark asset: $e');
      return null;
    }
  }

  /// Unique key for an XFile to identify it in cache
  String _cacheKey(XFile file) => file.path.isNotEmpty ? file.path : file.name;

  /// Starts background processing & upload immediately for selected photos.
  /// Runs asynchronously in the background without blocking the UI.
  void stageAndProcess(List<XFile> files) {
    if (files.isEmpty) return;

    for (final file in files) {
      final key = _cacheKey(file);
      if (_cache.containsKey(key)) continue;
      if (_inFlight.containsKey(key)) continue;

      _inFlight[key] = _processAndUploadSingle(file);
    }
  }

  /// Processes a single photo: read -> compress & watermark -> upload to Supabase
  Future<StagedPhotoResult?> _processAndUploadSingle(XFile file) async {
    final key = _cacheKey(file);
    try {
      final watermarkBytes = await _getWatermark();
      final originalBytes = await file.readAsBytes();

      // Fast single-pass compression + watermarking
      final compressed = await ImageCompressor.smartCompress(
        originalBytes,
        maxDimension: 1280,
        watermarkRawBytes: watermarkBytes,
      );

      final cleanName = file.name.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName.${compressed.fileExtension}';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('property_images').uploadBinary(
        fileName,
        compressed.bytes,
        fileOptions: FileOptions(contentType: compressed.mimeType),
      );

      final publicUrl = supabase.storage.from('property_images').getPublicUrl(fileName);

      final result = StagedPhotoResult(
        path: key,
        publicUrl: publicUrl,
        compressedSize: compressed.compressedSize,
      );

      _cache[key] = result;
      debugPrint('⚡ [PhotoPipeline] Background uploaded $key -> $publicUrl (${result.compressedSize ~/ 1024} KB)');
      return result;
    } catch (e) {
      debugPrint('[PhotoPipeline] Error processing photo $key: $e');
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Retrieves all URLs for the requested files.
  /// If already finished in the background: returns instantly (0ms)!
  /// If any are still in-flight: awaits their completion and emits live progress.
  Future<List<String>> getOrWaitForUrls(
    List<XFile> files, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final List<String> urls = [];
    final int total = files.length;
    if (total == 0) return urls;

    int completedCount = 0;

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final key = _cacheKey(file);

      StagedPhotoResult? staged = _cache[key];

      if (staged == null) {
        // If currently in-flight, wait for it
        if (_inFlight.containsKey(key)) {
          onProgress?.call(
            (completedCount / total * 0.75).clamp(0.05, 0.75),
            'Finalizing photo ${i + 1} of $total...',
          );
          staged = await _inFlight[key];
        } else {
          // If not started yet, process now
          onProgress?.call(
            (completedCount / total * 0.75).clamp(0.05, 0.75),
            'Processing photo ${i + 1} of $total...',
          );
          staged = await _processAndUploadSingle(file);
        }
      }

      if (staged != null) {
        urls.add(staged.publicUrl);
      } else {
        // Fallback: retry once directly if background hit an error
        try {
          final res = await _processAndUploadSingle(file);
          if (res != null) urls.add(res.publicUrl);
        } catch (_) {}
      }

      completedCount++;
      onProgress?.call(
        (completedCount / total * 0.80).clamp(0.1, 0.80),
        'Photo $completedCount of $total ready',
      );
    }

    return urls;
  }

  /// Checks if a file is already processed and uploaded
  bool isReady(XFile file) => _cache.containsKey(_cacheKey(file));

  /// Clears the staging cache (e.g. after successful post)
  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
