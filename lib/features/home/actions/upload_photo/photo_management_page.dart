import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task_model.dart';

// ─────────────────────────────────────────────
// Data model for a single photo entry
// ─────────────────────────────────────────────

class _PhotoEntry {
  final String url;
  final String caption;
  final String category;
  final DateTime uploadedAt;

  const _PhotoEntry({
    required this.url,
    required this.caption,
    required this.category,
    required this.uploadedAt,
  });

  static _PhotoEntry fromMap(Map<String, dynamic> map) {
    return _PhotoEntry(
      url: map['url'] as String? ?? '',
      caption: map['caption'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.tryParse(map['uploadedAt'] as String) ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        'caption': caption,
        'category': category,
        'uploadedAt': uploadedAt.toUtc().toIso8601String(),
      };
}

const _kCategories = [
  'All',
  'Before',
  'During',
  'After',
  'Issue',
  'Completed',
];

const _kUploadCategories = [
  'Before',
  'During',
  'After',
  'Issue',
  'Completed',
];

// ─────────────────────────────────────────────
// PhotoManagementPage
// ─────────────────────────────────────────────

class PhotoManagementPage extends StatefulWidget {
  final TaskModel project;
  final bool readOnly;

  const PhotoManagementPage({
    super.key,
    required this.project,
    this.readOnly = false,
  });

  @override
  State<PhotoManagementPage> createState() => _PhotoManagementPageState();
}

class _PhotoManagementPageState extends State<PhotoManagementPage> {
  String _selectedCategory = 'All';

  // ── Upload flow ──────────────────────────────────────────────────

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose where to pick your photos from',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: const Color(0xFF6C63FF),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    color: const Color(0xFFFF6B6B),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages(ImageSource source) async {
    final picker = ImagePicker();
    List<XFile> files = [];

    if (source == ImageSource.camera) {
      final photo =
          await picker.pickImage(source: source, imageQuality: 85);
      if (photo != null) files = [photo];
    } else {
      files = await picker.pickMultiImage(imageQuality: 85);
    }

    if (files.isEmpty) return;
    if (!mounted) return;

    // Show caption + category sheet before uploading
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoMetaSheet(fileCount: files.length),
    );

    if (result == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UploadProgressDialog(
        files: files,
        projectId: widget.project.taskId,
        caption: result['caption'] ?? '',
        category: result['category'] ?? 'General',
      ),
    );
  }

  // ── Delete ───────────────────────────────────────────────────────

  Future<void> _deletePhoto(
      BuildContext context, _PhotoEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Photo',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        content: const Text(
          'Are you sure you want to delete this photo? This cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Storage
      await FirebaseStorage.instance.refFromURL(entry.url).delete();

      // Remove from Firestore
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.project.taskId)
          .update({
        'photoEntries': FieldValue.arrayRemove([entry.toMap()]),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isBuilder = !widget.readOnly;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          '${widget.project.taskName} — Photos',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: isBuilder
          ? FloatingActionButton.extended(
              onPressed: _showSourcePicker,
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add Photos',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.project.taskId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load photos',
                  style: TextStyle(color: Colors.grey[500])),
            );
          }

          final data =
              snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final rawEntries =
              List<Map<String, dynamic>>.from(
                  (data['photoEntries'] as List? ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map)));
          final allPhotos =
              rawEntries.map(_PhotoEntry.fromMap).toList()
                ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

          final filtered = _selectedCategory == 'All'
              ? allPhotos
              : allPhotos
                  .where((p) => p.category == _selectedCategory)
                  .toList();

          return Column(
            children: [
              // ── Category filter bar ──────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _kCategories.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      final count = cat == 'All'
                          ? allPhotos.length
                          : allPhotos
                              .where((p) => p.category == cat)
                              .length;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C63FF)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6C63FF)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                            .withOpacity(0.25)
                                        : Colors.grey.shade300,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1),

              // ── Photo grid ───────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _selectedCategory == 'All'
                                  ? 'No photos yet'
                                  : 'No $_selectedCategory photos',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isBuilder
                                  ? 'Tap "Add Photos" to upload.'
                                  : 'Photos will appear here once uploaded.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            12, 12, 12, 100),
                        itemCount: filtered.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          return GestureDetector(
                            onTap: () => _openFullScreen(
                                filtered, index),
                            onLongPress: isBuilder
                                ? () =>
                                    _deletePhoto(context, entry)
                                : null,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Photo
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  child: Image.network(
                                    entry.url,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (_, child, progress) {
                                      if (progress == null)
                                        return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color:
                                                Color(0xFF6C63FF),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                          Icons
                                              .broken_image_outlined,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ),

                                // Category badge
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _categoryColor(
                                              entry.category)
                                          .withOpacity(0.85),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      entry.category,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                // Date stamp
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: ClipRRect(
                                    borderRadius:
                                        const BorderRadius.vertical(
                                      bottom: Radius.circular(10),
                                    ),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black
                                                .withOpacity(0.6),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        _formatDate(entry.uploadedAt),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openFullScreen(List<_PhotoEntry> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          photos: photos,
          initialIndex: initialIndex,
          readOnly: widget.readOnly,
          onDelete: widget.readOnly
              ? null
              : (entry) => _deletePhoto(context, entry),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  Color _categoryColor(String category) {
    switch (category) {
      case 'Before':
        return const Color(0xFF6C63FF);
      case 'During':
        return const Color(0xFFFFB347);
      case 'After':
        return const Color(0xFF43C59E);
      case 'Issue':
        return const Color(0xFFFF6B6B);
      case 'Completed':
        return const Color(0xFF43C59E);
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────
// Photo Meta Sheet (caption + category)
// ─────────────────────────────────────────────

class _PhotoMetaSheet extends StatefulWidget {
  final int fileCount;

  const _PhotoMetaSheet({required this.fileCount});

  @override
  State<_PhotoMetaSheet> createState() => _PhotoMetaSheetState();
}

class _PhotoMetaSheetState extends State<_PhotoMetaSheet> {
  final _captionController = TextEditingController();
  String _selectedCategory = 'During';

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.fileCount == 1
                  ? 'Photo Details'
                  : '${widget.fileCount} Photos — Details',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a caption and select a category',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            // Caption
            TextField(
              controller: _captionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Crack behind radiator on east wall',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF6C63FF), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Category chips
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kUploadCategories.map((cat) {
                final isSelected = cat == _selectedCategory;
                final color = _categoryChipColor(cat);
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : color.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'caption': _captionController.text.trim(),
                  'category': _selectedCategory,
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Upload',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryChipColor(String category) {
    switch (category) {
      case 'Before':
        return const Color(0xFF6C63FF);
      case 'During':
        return const Color(0xFFFFB347);
      case 'After':
        return const Color(0xFF43C59E);
      case 'Issue':
        return const Color(0xFFFF6B6B);
      case 'Completed':
        return const Color(0xFF43C59E);
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────
// Full Screen Gallery
// ─────────────────────────────────────────────

class _FullScreenGallery extends StatefulWidget {
  final List<_PhotoEntry> photos;
  final int initialIndex;
  final bool readOnly;
  final void Function(_PhotoEntry)? onDelete;

  const _FullScreenGallery({
    required this.photos,
    required this.initialIndex,
    required this.readOnly,
    this.onDelete,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.photos[_current];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.photos.length}',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        centerTitle: true,
        actions: [
          if (!widget.readOnly && widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFFF6B6B)),
              onPressed: () {
                widget.onDelete!(entry);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Photo viewer
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      widget.photos[index].url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Caption + metadata bar
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            _categoryColor(entry.category),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${entry.uploadedAt.day}/${entry.uploadedAt.month}/${entry.uploadedAt.year}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                if (entry.caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.caption,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Before':
        return const Color(0xFF6C63FF);
      case 'During':
        return const Color(0xFFFFB347);
      case 'After':
        return const Color(0xFF43C59E);
      case 'Issue':
        return const Color(0xFFFF6B6B);
      case 'Completed':
        return const Color(0xFF43C59E);
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────
// Upload Progress Dialog
// ─────────────────────────────────────────────

class _UploadProgressDialog extends StatefulWidget {
  final List<XFile> files;
  final String projectId;
  final String caption;
  final String category;

  const _UploadProgressDialog({
    required this.files,
    required this.projectId,
    required this.caption,
    required this.category,
  });

  @override
  State<_UploadProgressDialog> createState() =>
      _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> {
  int _uploaded = 0;
  bool _done = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _uploadAll();
  }

  Future<void> _uploadAll() async {
    final List<Map<String, dynamic>> entries = [];

    try {
      for (final file in widget.files) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance
            .ref()
            .child(
                'projects/${widget.projectId}/photos/$fileName');

        await ref.putFile(File(file.path));
        final url = await ref.getDownloadURL();

        entries.add(_PhotoEntry(
          url: url,
          caption: widget.caption,
          category: widget.category,
          uploadedAt: DateTime.now(),
        ).toMap());

        if (mounted) setState(() => _uploaded++);
      }

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.projectId)
          .update({
        'photoEntries': FieldValue.arrayUnion(entries),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.files.length;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasError) ...[
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF6B6B), size: 44),
              const SizedBox(height: 12),
              const Text('Upload Failed',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Text(_errorMessage,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ] else if (_done) ...[
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF43C59E), size: 44),
              const SizedBox(height: 12),
              Text(
                '$total ${total == 1 ? 'photo' : 'photos'} uploaded!',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
              ),
            ] else ...[
              const SizedBox(height: 4),
              const CircularProgressIndicator(
                  color: Color(0xFF6C63FF)),
              const SizedBox(height: 20),
              const Text('Uploading photos...',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Text('$_uploaded of $total uploaded',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : _uploaded / total,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Source Button
// ─────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}