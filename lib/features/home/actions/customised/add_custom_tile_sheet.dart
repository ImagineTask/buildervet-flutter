import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'custom_tile_model.dart';
import 'custom_tile_service.dart';

class AddCustomTileSheet extends StatefulWidget {
  final String projectId;
  final CustomTileService service;

  const AddCustomTileSheet({
    super.key,
    required this.projectId,
    required this.service,
  });

  @override
  State<AddCustomTileSheet> createState() => _AddCustomTileSheetState();
}

class _AddCustomTileSheetState extends State<AddCustomTileSheet> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  String _tileType = 'external'; // 'external' | 'internal_project'
  String _iconType = 'preset';
  String _iconValue = 'language';
  String _selectedColor = '#6C63FF';
  String? _uploadedImageUrl;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _presetIcons = [
    {'name': 'language', 'icon': Icons.language, 'label': 'Website'},
    {'name': 'store', 'icon': Icons.store_outlined, 'label': 'Store'},
    {'name': 'link', 'icon': Icons.link, 'label': 'Link'},
    {'name': 'social', 'icon': Icons.people_outline, 'label': 'Social'},
    {'name': 'email', 'icon': Icons.email_outlined, 'label': 'Email'},
    {'name': 'phone', 'icon': Icons.phone_outlined, 'label': 'Phone'},
    {'name': 'map', 'icon': Icons.map_outlined, 'label': 'Map'},
    {'name': 'document', 'icon': Icons.description_outlined, 'label': 'Doc'},
    {'name': 'video', 'icon': Icons.play_circle_outline, 'label': 'Video'},
    {'name': 'accounting', 'icon': Icons.calculate_outlined, 'label': 'Account'},
    {'name': 'legal', 'icon': Icons.gavel_outlined, 'label': 'Legal'},
    {'name': 'architecture', 'icon': Icons.architecture, 'label': 'Architect'},
  ];

  final List<String> _colors = [
    '#6C63FF', '#FF6B6B', '#43C59E', '#FFB347',
    '#4ECDC4', '#E056A0', '#1A1A2E', '#3498DB',
    '#E67E22', '#9B59B6',
  ];

  final List<String> _emojis = [
    '🌐', '🏠', '📱', '💼', '🛒', '📧', '📞',
    '📍', '📄', '🎥', '📅', '⭐', '🔗', '🎨',
    '🚀', '💡', '🔧', '📊', '🎯', '💬',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('custom_tiles/${widget.projectId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      setState(() {
        _uploadedImageUrl = url;
        _iconType = 'image';
        _iconValue = url;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter a name');
      return;
    }
    if (_tileType == 'external' && _urlController.text.trim().isEmpty) {
      _showSnack('Please enter a URL');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tile = CustomTileModel(
        id: '',
        projectId: widget.projectId,
        name: _nameController.text.trim(),
        tileType: _tileType,
        url: _tileType == 'external' ? _urlController.text.trim() : null,
        linkedProjectId: null, // TODO: implement project linking
        iconType: _iconType,
        iconValue: _iconValue,
        color: _selectedColor,
        createdAt: DateTime.now(),
      );

      await widget.service.addTile(tile);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Failed to save. Try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Custom Tile',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E)),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6C63FF)),
                        )
                      : const Text('Add',
                          style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tile type tabs
                  _label('Type'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeTab('External Link', 'external',
                          Icons.open_in_new_rounded),
                      const SizedBox(width: 8),
                      _typeTab('App Project', 'internal_project',
                          Icons.folder_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name
                  _label('Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDeco(
                        _tileType == 'external'
                            ? 'e.g. Our Website, Accountant'
                            : 'e.g. Accountant Services'),
                  ),
                  const SizedBox(height: 20),

                  // URL (external only)
                  if (_tileType == 'external') ...[
                    _label('URL'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: _inputDeco('https://example.com'),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Internal project placeholder
                  if (_tileType == 'internal_project') ...[
                    _label('Link to Project'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.grey[400], size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Project linking coming soon.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Icon type
                  _label('Icon'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _iconTypeTab('Preset', 'preset'),
                      const SizedBox(width: 8),
                      _iconTypeTab('Emoji', 'emoji'),
                      const SizedBox(width: 8),
                      _iconTypeTab('Image', 'image'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_iconType == 'preset') _presetIconSelector(),
                  if (_iconType == 'emoji') _emojiSelector(),
                  if (_iconType == 'image') _imageSelector(),
                  const SizedBox(height: 24),

                  // Color
                  _label('Color'),
                  const SizedBox(height: 12),
                  _colorPicker(),
                  const SizedBox(height: 24),

                  // Preview
                  _label('Preview'),
                  const SizedBox(height: 12),
                  _preview(),
                  const SizedBox(height: 32),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Add Tile',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E)));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
      );

  Widget _typeTab(String label, String type, IconData icon) {
    final isSelected = _tileType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tileType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTypeTab(String label, String type) {
    final isSelected = _iconType == type;
    return GestureDetector(
      onTap: () => setState(() => _iconType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? Colors.white : Colors.grey[600])),
      ),
    );
  }

  Widget _presetIconSelector() {
    final color =
        Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _presetIcons.map((item) {
        final isSelected =
            _iconType == 'preset' && _iconValue == item['name'];
        return GestureDetector(
          onTap: () => setState(() {
            _iconType = 'preset';
            _iconValue = item['name'];
          }),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.15)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? color : Colors.grey.shade200,
                  width: isSelected ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData,
                    color: isSelected ? color : Colors.grey[500],
                    size: 22),
                const SizedBox(height: 2),
                Text(item['label'] as String,
                    style: TextStyle(
                        fontSize: 9,
                        color:
                            isSelected ? color : Colors.grey[500])),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emojiSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _emojis.map((emoji) {
        final isSelected =
            _iconType == 'emoji' && _iconValue == emoji;
        return GestureDetector(
          onTap: () => setState(() {
            _iconType = 'emoji';
            _iconValue = emoji;
          }),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6C63FF).withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6C63FF)
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1),
            ),
            child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 22))),
          ),
        );
      }).toList(),
    );
  }

  Widget _imageSelector() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _uploadedImageUrl != null
                  ? const Color(0xFF6C63FF)
                  : Colors.grey.shade300,
              width: _uploadedImageUrl != null ? 2 : 1),
        ),
        child: _uploadedImageUrl != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_uploadedImageUrl!,
                        width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Text('Image uploaded',
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _uploadedImageUrl = null;
                      _iconType = 'preset';
                      _iconValue = 'language';
                    }),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.grey),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_outlined,
                      color: Colors.grey[400], size: 28),
                  const SizedBox(height: 4),
                  Text('Tap to upload image',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _colorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colors.map((hex) {
        final color =
            Color(int.parse(hex.replaceFirst('#', '0xFF')));
        final isSelected = _selectedColor == hex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = hex),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.5), blurRadius: 8)
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _preview() {
    final color =
        Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: _buildPreviewIcon(color),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _nameController.text.isEmpty
                  ? 'Name'
                  : _nameController.text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewIcon(Color color) {
    if (_iconType == 'emoji') {
      return Text(_iconValue, style: const TextStyle(fontSize: 18));
    } else if (_iconType == 'image' && _uploadedImageUrl != null) {
      return ClipOval(
        child: Image.network(_uploadedImageUrl!,
            width: 18, height: 18, fit: BoxFit.cover),
      );
    } else {
      const iconMap = {
        'language': Icons.language,
        'store': Icons.store_outlined,
        'link': Icons.link,
        'social': Icons.people_outline,
        'email': Icons.email_outlined,
        'phone': Icons.phone_outlined,
        'map': Icons.map_outlined,
        'document': Icons.description_outlined,
        'video': Icons.play_circle_outline,
        'accounting': Icons.calculate_outlined,
        'legal': Icons.gavel_outlined,
        'architecture': Icons.architecture,
      };
      return Icon(iconMap[_iconValue] ?? Icons.language,
          color: color, size: 18);
    }
  }
}
