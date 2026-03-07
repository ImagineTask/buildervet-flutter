import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class SeeAllScreen extends ConsumerStatefulWidget {
  final bool isProjects;

  const SeeAllScreen({super.key, required this.isProjects});

  @override
  ConsumerState<SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends ConsumerState<SeeAllScreen> {
  String _searchQuery = '';

  /// Show confirmation dialog, select the card, and go back
  Future<void> _confirmAndSelect(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                task.isProject ? Icons.folder : Icons.task_alt,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select ${task.isProject ? "Project" : "Task"}?',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.taskName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  DateUtils2.dateRange(task.startTime, task.endTime),
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                if (task.guidePrice != null) ...[
                  const Spacer(),
                  Text(
                    CurrencyUtils.formatPriceCompact(task.guidePrice!),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Update selection
      if (widget.isProjects) {
        ref.read(selectedProjectIdProvider.notifier).state = task.taskId;
      } else {
        ref.read(selectedTaskIdProvider.notifier).state = task.taskId;
      }
      // Go back to home
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = widget.isProjects
        ? ref.watch(projectsProvider)
        : ref.watch(allTasksProvider);

    final selectedId = widget.isProjects
        ? ref.watch(selectedProjectIdProvider)
        : ref.watch(selectedTaskIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isProjects ? 'All Projects' : 'All Tasks'),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchBar(
              hintText: widget.isProjects
                  ? 'Search projects...'
                  : 'Search tasks...',
              onChanged: (query) {
                setState(() => _searchQuery = query.toLowerCase());
              },
            ),
          ),

          // List
          Expanded(
            child: dataAsync.when(
              data: (items) {
                var filtered = widget.isProjects
                    ? items
                    : items.where((t) => !t.isProject).toList();

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((t) {
                    return t.taskName.toLowerCase().contains(_searchQuery) ||
                        t.description.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No results found',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'Nothing here yet',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    final isSelected = task.taskId == selectedId;

                    return _ListCard(
                      task: task,
                      isSelected: isSelected,
                      onTap: () {
                        if (!isSelected) {
                          _confirmAndSelect(task);
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const LoadingIndicator(),
              error: (err, _) => ErrorView(message: err.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── List Card ───────────────────────────────────────────

class _ListCard extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final VoidCallback onTap;

  const _ListCard({
    required this.task,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: isSelected ? AppColors.primary.withOpacity(0.03) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : task.status.color.withOpacity(0.1),
          child: isSelected
              ? Icon(Icons.check, color: AppColors.primary, size: 20)
              : Text(
                  task.taskName.isNotEmpty
                      ? task.taskName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: task.status.color,
                  ),
                ),
        ),
        title: Text(
          task.taskName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          task.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: isSelected
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: const Text(
                  'Selected',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : StatusBadge(status: task.status),
      ),
    );
  }
}