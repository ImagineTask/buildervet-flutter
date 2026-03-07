import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class ProjectPhotoScreen extends ConsumerWidget {
  final String projectId;

  const ProjectPhotoScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(taskByIdProvider(projectId));
    final subtasksAsync = ref.watch(projectTasksProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos'),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Toggle grid/list view
            },
            icon: const Icon(Icons.grid_view),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showUploadOptions(context);
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text('Add Photo'),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const ErrorView(message: 'Project not found');
          }
          return _PhotoContent(
            project: project,
            subtasksAsync: subtasksAsync,
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Add Photo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _UploadOption(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                subtitle: 'Use your camera',
                color: const Color(0xFF45B7D1),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Open camera
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _UploadOption(
                icon: Icons.photo_library,
                label: 'Choose from Gallery',
                subtitle: 'Select existing photos',
                color: const Color(0xFF6C5CE7),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Open gallery
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _UploadOption(
                icon: Icons.folder,
                label: 'Upload from Files',
                subtitle: 'Browse your documents',
                color: const Color(0xFFFFA502),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Open file picker
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Photo Content ───────────────────────────────────────

class _PhotoContent extends StatelessWidget {
  final Task project;
  final AsyncValue<List<Task>> subtasksAsync;

  const _PhotoContent({
    required this.project,
    required this.subtasksAsync,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with real photo data from backend
    // For now, show empty state and subtask photo sections
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project-level photos
          Text(
            'Project Photos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Before & after photos of the overall project',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _EmptyPhotoGrid(
            message: 'No project photos yet',
            subtitle: 'Tap the button below to add your first photo',
          ),
          const SizedBox(height: AppSpacing.lg),

          // Task-level photos
          Text(
            'Task Photos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Photos from individual tasks',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          subtasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return _EmptyPhotoGrid(
                  message: 'No tasks yet',
                  subtitle: 'Task photos will appear here',
                );
              }

              return Column(
                children: tasks.map((task) {
                  return _TaskPhotoSection(task: task);
                }).toList(),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, _) => ErrorView(message: err.toString()),
          ),

          // Bottom padding for FAB
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Task Photo Section ──────────────────────────────────

class _TaskPhotoSection extends StatelessWidget {
  final Task task;

  const _TaskPhotoSection({required this.task});

  @override
  Widget build(BuildContext context) {
    // TODO: Read actual photos from task.metadata or photo model
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  task.taskName.isNotEmpty ? task.taskName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  task.taskName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // TODO: Upload photo for this specific task
                },
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Empty state for this task's photos
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Text(
                'No photos',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Photo Grid ────────────────────────────────────

class _EmptyPhotoGrid extends StatelessWidget {
  final String message;
  final String subtitle;

  const _EmptyPhotoGrid({
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
