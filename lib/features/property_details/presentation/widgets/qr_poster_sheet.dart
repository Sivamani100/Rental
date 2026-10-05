import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
class QrPosterSheet extends StatefulWidget {
  final PropertyModel property;
  final String shareUrl;

  const QrPosterSheet({
    Key? key,
    required this.property,
    required this.shareUrl,
  }) : super(key: key);

  @override
  State<QrPosterSheet> createState() => _QrPosterSheetState();
}

class _QrPosterSheetState extends State<QrPosterSheet> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;

  Future<void> _shareOrDownloadPoster() async {
    setState(() => _isGenerating = true);
    
    try {
      // 1. Wait a frame for rendering
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 2. Render boundary to image
      RenderRepaintBoundary boundary = _posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      
      // 3. Convert to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      
      if (kIsWeb) {
        // Web: Trigger browser download directly from memory
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'rental_poster_${widget.property.id}.png',
        );
        await xFile.saveTo('rental_poster_${widget.property.id}.png');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poster downloaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Mobile: Save to temp file then to Gallery
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/poster_${widget.property.id}.png');
        await file.writeAsBytes(pngBytes);
        
        await Gal.putImage(file.path, album: 'Rental App');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poster successfully saved to gallery!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      
    } catch (e) {
      debugPrint('Error generating poster: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save poster: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Property Poster',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Poster Preview (Scaled down for sheet)
          Container(
            height: 450,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _posterKey,
                  child: _buildA4Poster(),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _shareOrDownloadPoster,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: 0,
              ),
              child: _isGenerating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Text(
                      'Download Poster',
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Actual A4 size aspect ratio design (approx 1:1.414)
  Widget _buildA4Poster() {
    final now = DateTime.now();
    final versionStr = 'VERSION: V${now.year}.${now.month.toString().padLeft(2, '0')}';
    
    final propertyTypeName = widget.property.type == 'PG' 
        ? 'hostel/pg' 
        : (widget.property.type == 'Buy' || widget.property.type == 'Sale' 
            ? 'property' 
            : 'rental home');
    
    return Container(
      width: 595, // standard A4 width in pt
      height: 842, // standard A4 height in pt
      color: Colors.white,
      child: Stack(
        children: [
          // Background Design
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo + App Name
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rental App',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'List your property',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade500,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Top Right Info
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'rental.arkio.in',
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            versionStr,
                            style: TextStyle(
                              fontFamily: GoogleFonts.inter().fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade400,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Top Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.only(top: 24),
                ),
                
                const Spacer(flex: 1),
                
                // Headings
                // Property Name as Headline
                Text(
                  widget.property.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.1,
                    letterSpacing: -1,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 0.5, offset: Offset(0.5, 0.5)),
                      Shadow(color: Colors.black, blurRadius: 0.5, offset: Offset(-0.5, -0.5)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Scan this QR code to leave a review and share your\nfeedback about this $propertyTypeName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w500, // Slightly lighter than w600 for better contrast against the bold title
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // QR Code
                Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: widget.shareUrl,
                      version: QrVersions.auto,
                      size: 340.0,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: Colors.black,
                      ),
                    ),
                    // Custom embedded logo with border and clearance
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white, // 3px white clearance around the stroke
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300, width: 2), // The simple line/stroke
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14), // slightly smaller to fit inside border smoothly
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Find homes and pgs near you through Rental App.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.only(bottom: 16),
                ),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFooterFeature(CupertinoIcons.check_mark_circled, 'Verified property listing.'),
                        const SizedBox(height: 4),
                        _buildFooterFeature(CupertinoIcons.bolt, 'Instant contact to owner.'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'POWERED BY',
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rental App',
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black87),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

