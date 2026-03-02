import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

/// What happens when the user taps a task in the list
enum TaskListMode {
  detail,
  quote,
  schedule,
  invoice,
}

extension TaskListModeExt on TaskListMode {
  String get title {
    switch (this) {
      case TaskListMode.detail:
        return 'Tasks';
      case TaskListMode.quote:
        return 'Quotes';
      case TaskListMode.schedule:
        return 'Schedule';
      case TaskListMode.invoice:
        return 'Invoices';
    }
  }

  String get subtitle {
    switch (this) {
      case TaskListMode.detail:
        return 'Select a task to view details';
      case TaskListMode.quote:
        return 'Select a task to manage quotes';
      case TaskListMode.schedule:
        return 'Select a task to manage schedule';
      case TaskListMode.invoice:
        return 'Select a task to manage invoices';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskListMode.detail:
        return Icons.list_alt;
      case TaskListMode.quote:
        return Icons.request_quote;
      case TaskListMode.schedule:
        return Icons.calendar_month;
      case TaskListMode.invoice:
        return Icons.receipt_long;
    }
  }

  Color get accentColor {
    switch (this) {
      case TaskListMode.detail:
        return AppColors.primary;
      case TaskListMode.quote:
        return const Color(0xFFFF6B6B);
      case TaskListMode.schedule:
        return const Color(0xFF45B7D1);
      case TaskListMode.invoice:
        return const Color(0xFF6C5CE7);
    }
  }
}

/// Reusable task list screen for project actions.
/// Same list of subtasks, different destination on tap.
class ProjectTaskListScreen extends ConsumerStatefulWidget {
  final String projectId;
  final TaskListMode mode;

  const ProjectTaskListScreen({
    super.key,
    required this.projectId,
    required this.mode,
  });

  @override
  ConsumerState<ProjectTaskListScreen> createState() =>
      _ProjectTaskListScreenState();
}

class _ProjectTaskListScreenState
    extends ConsumerState<ProjectTaskListScreen> {
  String _searchQuery = '';

  void _onTaskTap(Task task) {
    switch (widget.mode) {
      case TaskListMode.detail:
        context.push('/actions/task-detail/${task.taskId}');
        break;
      case TaskListMode.quote:
        context.push('/actions/task-quote/${task.taskId}');
        break;
      case TaskListMode.schedule:
        context.push('/actions/task-schedule/${task.taskId}');
        break;
      case TaskListMode.invoice:
        context.push('/actions/task-invoice/${task.taskId}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectId));
    final projectAsync = ref.watch(taskByIdProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project name
            projectAsync.when(
              data: (project) => Text(
                project?.taskName ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            // Mode title
            Text(
              widget.mode.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode description
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(widget.mode.icon, size: 18, color: widget.mode.accentColor),
                const SizedBox(width: 8),
                Text(
                  widget.mode.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSearchBar(
              hintText: 'Search tasks...',
              onChanged: (query) {
                setState(() => _searchQuery = query.toLowerCase());
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Task list
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                var filtered = tasks.toList();

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((t) {
                    return t.taskName.toLowerCase().contains(_searchQuery) ||
                        t.description.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: widget.mode.icon,
                    title: 'No tasks found',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'This project has no tasks yet',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return _TaskListItem(
                      task: task,
                      mode: widget.mode,
                      onTap: () => _onTaskTap(task),
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

// ─── Task List Item ──────────────────────────────────────
// Shows different secondary info based on the mode

class _TaskListItem extends StatelessWidget {
  final Task task;
  final TaskListMode mode;
  final VoidCallback onTap;

  const _TaskListItem({
    required this.task,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + status
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: mode.accentColor.withOpacity(0.1),
                    child: Icon(mode.icon, size: 18, color: mode.accentColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      task.taskName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Mode-specific info
              _buildModeInfo(context),

              const SizedBox(height: AppSpacing.xs),

              // Bottom row: date + action hint
              Row(
                children: [
                  Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    DateUtils2.dateRange(task.startTime, task.endTime),
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: mode.accentColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeInfo(BuildContext context) {
    switch (mode) {
      case TaskListMode.detail:
        return Text(
          task.description,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

      case TaskListMode.quote:
        final quoteCount = task.quotes.length;
        final pendingCount = task.pendingQuoteCount;
        return Row(
          children: [
            Icon(Icons.request_quote, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              quoteCount == 0
                  ? 'No quotes yet'
                  : '$quoteCount quote${quoteCount > 1 ? 's' : ''} ($pendingCount pending)',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (task.guidePrice != null) ...[
              const Spacer(),
              Text(
                'Guide: ${CurrencyUtils.formatPriceCompact(task.guidePrice!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );

      case TaskListMode.schedule:
        final days = task.durationDays;
        return Row(
          children: [
            Icon(Icons.timer_outlined, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              days != null ? '$days days' : 'No dates set',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        );

      case TaskListMode.invoice:
        // TODO: When invoice model exists, show invoice status
        return Row(
          children: [
            Icon(Icons.receipt, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              task.guidePrice != null
                  ? 'Est. ${CurrencyUtils.formatPriceCompact(task.guidePrice!)}'
                  : 'No estimate',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        );
    }
  }
}
