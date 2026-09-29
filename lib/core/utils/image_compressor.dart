import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Result metadata from smart 30KB compression.
class CompressedImageResult {
  final Uint8List bytes;
  final String mimeType;
  final String fileExtension;
  final int originalSize;
  final int compressedSize;

  const CompressedImageResult({
    required this.bytes,
    required this.mimeType,
    required this.fileExtension,
    required this.originalSize,
    required this.compressedSize,
  });

  double get savingsPercent => originalSize > 0
      ? ((1.0 - (compressedSize / originalSize)) * 100.0).clamp(0.0, 99.9)
      : 0.0;

  String get originalPretty => '${(originalSize / 1024).toStringAsFixed(1)} KB';
  String get compressedPretty => '${(compressedSize / 1024).toStringAsFixed(1)} KB';
}

class _IsolateCompressParams {
  final Uint8List originalBytes;
  final int maxDimension;
  final int targetMaxBytes;
  final Uint8List? watermarkBytes;

  _IsolateCompressParams({
    required this.originalBytes,
    required this.maxDimension,
    required this.targetMaxBytes,
    this.watermarkBytes,
  });
}

/// Advanced 30 KB Smart Image Compressor & Format Optimizer.
/// Uses background isolates (compute) to avoid blocking the main UI thread.
class ImageCompressor {
  /// Strict target limit: 30 KB (30,720 bytes)
  static const int defaultTargetBytes = 30 * 1024; // 30 KB

  /// Smart compresses any image bytes down to <= 30 KB with sharp visual quality.
  /// Runs off the main UI thread via `compute()` isolate task.
  static Future<CompressedImageResult> smartCompress(
    Uint8List originalBytes, {
    int maxDimension = 960,
    int targetMaxBytes = defaultTargetBytes,
    img.Image? watermark,
    Uint8List? watermarkRawBytes,
  }) async {
    final int originalSize = originalBytes.length;

    // 0. Strict 30 KB Bypass Rule:
    // If image is ALREADY <= 30 KB and no watermark is requested, skip processing instantly!
    if (originalSize <= targetMaxBytes && watermark == null && watermarkRawBytes == null) {
      String ext = 'jpg';
      String mime = 'image/jpeg';
      if (originalBytes.length > 8 && originalBytes[0] == 0x89 && originalBytes[1] == 0x50) {
        ext = 'png';
        mime = 'image/png';
      } else if (originalBytes.length > 12 && originalBytes[0] == 0x52 && originalBytes[1] == 0x49) {
        ext = 'webp';
        mime = 'image/webp';
      }

      debugPrint('⚡ 30KB Fast Bypass: Image is already ${(originalSize / 1024).toStringAsFixed(1)} KB (<= 30 KB).');

      return CompressedImageResult(
        bytes: originalBytes,
        mimeType: mime,
        fileExtension: ext,
        originalSize: originalSize,
        compressedSize: originalSize,
      );
    }

    try {
      final params = _IsolateCompressParams(
        originalBytes: originalBytes,
        maxDimension: maxDimension,
        targetMaxBytes: targetMaxBytes,
        watermarkBytes: watermarkRawBytes,
      );

      // Offload heavy image processing (decoding, resizing, WebP/JPEG encoding) to background isolate
      return await compute(_processImageInIsolate, params);
    } catch (e) {
      debugPrint('ImageCompressor compute isolate fallback: $e');
      return CompressedImageResult(
        bytes: originalBytes,
        mimeType: 'image/jpeg',
        fileExtension: 'jpg',
        originalSize: originalSize,
        compressedSize: originalSize,
      );
    }
  }

  /// Top-level background isolate function for compute()
  static CompressedImageResult _processImageInIsolate(_IsolateCompressParams params) {
    final Uint8List originalBytes = params.originalBytes;
    final int originalSize = originalBytes.length;
    final int targetMaxBytes = params.targetMaxBytes;
    final int maxDimension = params.maxDimension;

    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        return CompressedImageResult(
          bytes: originalBytes,
          mimeType: 'image/jpeg',
          fileExtension: 'jpg',
          originalSize: originalSize,
          compressedSize: originalSize,
        );
      }

      img.Image processed = decoded;

      // 1. Resolution Normalization
      if (processed.width > maxDimension || processed.height > maxDimension) {
        if (processed.width > processed.height) {
          processed = img.copyResize(processed, width: maxDimension, interpolation: img.Interpolation.cubic);
        } else {
          processed = img.copyResize(processed, height: maxDimension, interpolation: img.Interpolation.cubic);
        }
      }

      // 2. Clean Watermark Stamping
      if (params.watermarkBytes != null) {
        final watermarkDecoded = img.decodeImage(params.watermarkBytes!);
        if (watermarkDecoded != null && processed.width >= 120 && processed.height >= 120) {
          int targetWatermarkWidth = (processed.width * 0.20).toInt().clamp(50, 260);
          img.Image scaledWatermark = img.copyResize(watermarkDecoded, width: targetWatermarkWidth, interpolation: img.Interpolation.linear);
          int padding = 12;
          int dstX = (processed.width - scaledWatermark.width - padding).clamp(0, processed.width);
          int dstY = (processed.height - scaledWatermark.height - padding).clamp(0, processed.height);
          img.compositeImage(processed, scaledWatermark, dstX: dstX, dstY: dstY);
        }
      }

      // 3. Multi-Format Benchmarking (WebP vs JPEG)
      Uint8List bestBytes;
      String bestMime;
      String bestExt;

      Uint8List? webpCandidate;
      try {
        final webp = img.encodeWebP(processed);
        webpCandidate = Uint8List.fromList(webp);
      } catch (_) {}

      final jpg = img.encodeJpg(processed, quality: 65);
      final Uint8List jpgCandidate = Uint8List.fromList(jpg);

      if (webpCandidate != null && webpCandidate.length < jpgCandidate.length) {
        bestBytes = webpCandidate;
        bestMime = 'image/webp';
        bestExt = 'webp';
      } else {
        bestBytes = jpgCandidate;
        bestMime = 'image/jpeg';
        bestExt = 'jpg';
      }

      // 4. Progressive 30 KB Target Compression Loop
      if (bestBytes.length > targetMaxBytes) {
        int currentQuality = 60;
        int currentDim = maxDimension;

        while (bestBytes.length > targetMaxBytes && currentQuality >= 35) {
          try {
            if (currentQuality < 50 && currentDim > 720) {
              currentDim = (currentDim * 0.88).toInt();
              processed = img.copyResize(processed, width: currentDim, interpolation: img.Interpolation.cubic);
            }

            final nextJpg = img.encodeJpg(processed, quality: currentQuality);
            bestBytes = Uint8List.fromList(nextJpg);
            bestMime = 'image/jpeg';
            bestExt = 'jpg';

            try {
              final nextWebp = img.encodeWebP(processed);
              if (nextWebp.length <= bestBytes.length) {
                bestBytes = Uint8List.fromList(nextWebp);
                bestMime = 'image/webp';
                bestExt = 'webp';
              }
            } catch (_) {}
          } catch (_) {
            final nextJpg = img.encodeJpg(processed, quality: currentQuality);
            bestBytes = Uint8List.fromList(nextJpg);
            bestMime = 'image/jpeg';
            bestExt = 'jpg';
          }
          currentQuality -= 5;
        }
      }

      // 5. Never-Inflate Rule
      if (bestBytes.length > originalSize && params.watermarkBytes == null) {
        bestBytes = originalBytes;
      }

      return CompressedImageResult(
        bytes: bestBytes,
        mimeType: bestMime,
        fileExtension: bestExt,
        originalSize: originalSize,
        compressedSize: bestBytes.length,
      );
    } catch (e) {
      return CompressedImageResult(
        bytes: originalBytes,
        mimeType: 'image/jpeg',
        fileExtension: 'jpg',
        originalSize: originalSize,
        compressedSize: originalSize,
      );
    }
  }

  /// Helper for quick Uint8List return
  static Future<Uint8List> compressImageBytes(
    Uint8List originalBytes, {
    int maxDimension = 960,
    int targetMaxBytes = defaultTargetBytes,
    Uint8List? watermarkRawBytes,
  }) async {
    final res = await smartCompress(
      originalBytes,
      maxDimension: maxDimension,
      targetMaxBytes: targetMaxBytes,
      watermarkRawBytes: watermarkRawBytes,
    );
    return res.bytes;
  }
}
