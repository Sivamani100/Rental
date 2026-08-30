import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';

class PhotoItem {
  final XFile? file;
  final String? url;

  PhotoItem({this.file, this.url});

  bool get isNetwork => url != null && url!.isNotEmpty;
  String get displayPath => isNetwork ? url! : (file?.path ?? '');
}

class PhotoPositionScreen extends StatefulWidget {
  final List<XFile> localImages;
  final List<String> existingUrls;

  const PhotoPositionScreen({
    super.key,
    required this.localImages,
    this.existingUrls = const [],
  });

  @override
  State<PhotoPositionScreen> createState() => _PhotoPositionScreenState();
}

class _PhotoPositionScreenState extends State<PhotoPositionScreen> {
  final ImagePicker _picker = ImagePicker();
  late List<PhotoItem> _photos;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _photos = [
      ...widget.existingUrls.map((u) => PhotoItem(url: u)),
      ...widget.localImages.map((f) => PhotoItem(file: f)),
    ];
  }

  Future<void> _addMorePhotos() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() {
          _photos.addAll(picked.map((f) => PhotoItem(file: f)));
          _selectedIndex = _photos.length - 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    }
  }

  void _setAsCover(int index) {
    if (index == 0 || index >= _photos.length) return;
    setState(() {
      final item = _photos.removeAt(index);
      _photos.insert(0, item);
      _selectedIndex = 0;
    });
  }

  void _movePhoto(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _photos.length) return;
    setState(() {
      final item = _photos.removeAt(fromIndex);
      _photos.insert(toIndex, item);
      _selectedIndex = toIndex;
    });
  }

  void _deletePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _photos.removeAt(index);
      if (_selectedIndex >= _photos.length) {
        _selectedIndex = (_photos.length - 1).clamp(0, _photos.length);
      }
    });
  }

  void _finishAndSave() {
    final List<XFile> reorderedLocal = [];
    final List<String> reorderedExisting = [];

    for (final item in _photos) {
      if (item.isNetwork) {
        reorderedExisting.add(item.url!);
      } else if (item.file != null) {
        reorderedLocal.add(item.file!);
      }
    }

    Navigator.pop(context, {
      'localImages': reorderedLocal,
      'existingUrls': reorderedExisting,
    });
  }

  ImageProvider _getImageProvider(PhotoItem item) {
    if (item.isNetwork) {
      return NetworkImage(item.url!);
    } else if (kIsWeb) {
      return NetworkImage(item.file!.path);
    } else {
      return FileImage(File(item.file!.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Position & Reorder Photos',
          style: GoogleFonts.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _photos.isEmpty ? null : _finishAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.gallery_slash,
                    size: 56,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Photos Selected',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add photos to position and set your cover',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _addMorePhotos,
                    icon: const Icon(Iconsax.add, size: 18),
                    label: const Text('Add Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryYellow,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Top Info Bar / Hint
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isDark ? AppTheme.darkCardElevated : const Color(0xFFFFFDE7),
                  child: Row(
                    children: [
                      const Icon(Iconsax.info_circle, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drag or tap arrows to reposition. #1 is your primary cover photo.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF78350F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Selected Photo Preview Viewport
                Expanded(
                  flex: 5,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_photos.isNotEmpty && _selectedIndex < _photos.length)
                            Image(
                              image: _getImageProvider(_photos[_selectedIndex]),
                              fit: BoxFit.contain,
                            ),

                          // Top-Left Badge: Cover or Photo Position Number
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedIndex == 0
                                    ? AppTheme.primaryYellow
                                    : Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedIndex == 0 ? Icons.star_rounded : Iconsax.image,
                                    size: 15,
                                    color: _selectedIndex == 0 ? Colors.black : Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _selectedIndex == 0
                                        ? 'MAIN COVER PHOTO'
                                        : 'PHOTO ${_selectedIndex + 1} OF ${_photos.length}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedIndex == 0 ? Colors.black : Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Action Toolbar for Active Photo
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left Arrow
                                  IconButton(
                                    tooltip: 'Move Left',
                                    icon: const Icon(Iconsax.arrow_left_2, size: 20),
                                    onPressed: _selectedIndex > 0
                                        ? () => _movePhoto(_selectedIndex, _selectedIndex - 1)
                                        : null,
                                  ),

                                  // Make Cover Action
                                  if (_selectedIndex != 0)
                                    BouncingButton(
                                      onTap: () => _setAsCover(_selectedIndex),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryYellow,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: Colors.black,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Set as Cover',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Iconsax.tick_circle,
                                          size: 16,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Main Cover Active',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Right Arrow
                                  IconButton(
                                    tooltip: 'Move Right',
                                    icon: const Icon(Iconsax.arrow_right_3, size: 20),
                                    onPressed: _selectedIndex < _photos.length - 1
                                        ? () => _movePhoto(_selectedIndex, _selectedIndex + 1)
                                        : null,
                                  ),

                                  // Delete Button
                                  IconButton(
                                    tooltip: 'Delete Photo',
                                    icon: const Icon(Iconsax.trash, size: 20, color: Colors.redAccent),
                                    onPressed: () => _deletePhoto(_selectedIndex),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Thumbnail Reorder Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reorder Photos (${_photos.length})',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addMorePhotos,
                            icon: Icon(
                              Iconsax.gallery_add,
                              size: 16,
                              color: isDark ? AppTheme.primaryYellow : Colors.black,
                            ),
                            label: Text(
                              'Add More',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.primaryYellow : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 96,
                        child: ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _photos.removeAt(oldIndex);
                              _photos.insert(newIndex, item);
                              _selectedIndex = newIndex;
                            });
                          },
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            final bool isCover = index == 0;
                            final bool isCurrent = index == _selectedIndex;

                            return BouncingButton(
                              key: ValueKey('photo_${photo.displayPath}_$index'),
                              onTap: () => setState(() => _selectedIndex = index),
                              child: Container(
                                width: 84,
                                height: 96,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCover
                                        ? AppTheme.primaryYellow
                                        : (isCurrent
                                            ? (isDark ? Colors.white : Colors.black)
                                            : Colors.transparent),
                                    width: isCover || isCurrent ? 2.5 : 0,
                                  ),
                                  boxShadow: [
                                    if (isCover || isCurrent)
                                      BoxShadow(
                                        color: (isCover ? AppTheme.primaryYellow : Colors.black)
                                            .withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11.5),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image(
                                        image: _getImageProvider(photo),
                                        fit: BoxFit.cover,
                                      ),

                                      // Index number badge (e.g. #1, #2...)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCover
                                                ? AppTheme.primaryYellow
                                                : Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isCover ? 'Cover' : '#${index + 1}',
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: isCover ? Colors.black : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Small Delete cross
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _deletePhoto(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(2.5),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
