import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/task.dart';
import '../models/custom_action.dart';

/// Bottom sheet for creating a custom user action.
/// Returns a [CustomAction] via Navigator.pop when saved.
///
/// Usage:
/// ```dart
/// final action = await showModalBottomSheet<CustomAction>(
///   builder: (context) => AddCustomActionSheet(task: task),
/// );
/// if (action != null) { /* use it */ }
/// ```
class AddCustomActionSheet extends StatefulWidget {
  final Task task;

  const AddCustomActionSheet({super.key, required this.task});

  @override
  State<AddCustomActionSheet> createState() => _AddCustomActionSheetState();
}

class _AddCustomActionSheetState extends State<AddCustomActionSheet> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  String _selectedType = 'web';
  bool _shared = false;
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;

  static const _iconOptions = [
    Icons.language,
    Icons.link,
    Icons.phone,
    Icons.note,
    Icons.shopping_cart,
    Icons.build,
    Icons.home,
    Icons.lightbulb,
    Icons.attach_money,
    Icons.description,
    Icons.camera_alt,
    Icons.map,
  ];

  static const _colorOptions = [
    Color(0xFF6366F1),
    Color(0xFFFF6B6B),
    Color(0xFF45B7D1),
    Color(0xFF00B894),
    Color(0xFFFECA57),
    Color(0xFF6C5CE7),
    Color(0xFFE17055),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final action = CustomAction(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: name,
      type: _selectedType,
      url: _selectedType != 'note' ? _urlController.text.trim() : null,
      icon: _iconOptions[_selectedIconIndex],
      color: _colorOptions[_selectedColorIndex],
      shared: _shared,
      taskId: widget.task.taskId,
    );

    Navigator.pop(context, action);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Create Custom Action',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'For: ${widget.task.taskName}',
                style: TextStyle(fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Action Name',
                  hintText: 'e.g. Check Building Regs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Type selector
              Text(
                'Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _TypeChip(
                    icon: Icons.language,
                    label: 'Web Link',
                    isSelected: _selectedType == 'web',
                    onTap: () => setState(() => _selectedType = 'web'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TypeChip(
                    icon: Icons.phone,
                    label: 'Phone',
                    isSelected: _selectedType == 'phone',
                    onTap: () => setState(() => _selectedType = 'phone'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TypeChip(
                    icon: Icons.note,
                    label: 'Note',
                    isSelected: _selectedType == 'note',
                    onTap: () => setState(() => _selectedType = 'note'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // URL / Phone input
              if (_selectedType == 'web')
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://example.com',
                    prefixIcon: const Icon(Icons.link, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                ),
              if (_selectedType == 'phone')
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+44 7700 900000',
                    prefixIcon: const Icon(Icons.phone, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                ),
              if (_selectedType != 'note')
                const SizedBox(height: AppSpacing.md),

              // Icon picker
              Text(
                'Icon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(_iconOptions.length, (index) {
                  final isSelected = _selectedIconIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconIndex = index),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _colorOptions[_selectedColorIndex].withOpacity(0.15)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? _colorOptions[_selectedColorIndex]
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _iconOptions[index],
                        size: 20,
                        color: isSelected
                            ? _colorOptions[_selectedColorIndex]
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),

              // Colour picker
              Text(
                'Colour',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(_colorOptions.length, (index) {
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _colorOptions[index],
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _colorOptions[index].withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),

              // Share toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      _shared ? Icons.people : Icons.person,
                      size: 20,
                      color: _shared ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shared ? 'Shared with team' : 'Just for me',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _shared ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _shared
                                ? 'All participants can see this action'
                                : 'Only visible to you',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _shared,
                      onChanged: (val) => setState(() => _shared = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Preview
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: SizedBox(
                  width: 100,
                  height: 90,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _colorOptions[_selectedColorIndex].withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: _colorOptions[_selectedColorIndex].withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _colorOptions[_selectedColorIndex].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Icon(
                            _iconOptions[_selectedIconIndex],
                            color: _colorOptions[_selectedColorIndex],
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nameController.text.isEmpty
                              ? 'Action Name'
                              : _nameController.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _nameController.text.isEmpty
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  child: const Text('Create Action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Type Chip ───────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}