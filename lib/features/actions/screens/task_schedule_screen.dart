import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskScheduleScreen extends ConsumerWidget {
  final String taskId;

  const TaskScheduleScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
      ),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const ErrorView(message: 'Task not found');
          }
          return _ScheduleContent(task: task);
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  final Task task;

  const _ScheduleContent({required this.task});

  @override
  Widget build(BuildContext context) {
    final days = task.durationDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge(status: task.status),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Timeline visual
          Text(
            'Timeline',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),

          // Start date
          _DateCard(
            icon: Icons.flag_outlined,
            label: 'Start Date',
            date: task.startTime,
            color: const Color(0xFF00B894),
            onEdit: () {
              // TODO: Pick new start date
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Duration indicator
          Container(
            margin: const EdgeInsets.only(left: 24),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  days != null ? '$days days duration' : 'Duration not set',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // End date
          _DateCard(
            icon: Icons.flag,
            label: 'End Date',
            date: task.endTime,
            color: const Color(0xFFFF6B6B),
            onEdit: () {
              // TODO: Pick new end date
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Progress indicator
          if (days != null) ...[
            Text(
              'Progress',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _ProgressCard(task: task, totalDays: days),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Participants involved
          if (task.participants.isNotEmpty) ...[
            Text(
              'Assigned People',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: task.participants.map((p) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  label: Text(p.name, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Reschedule
                  },
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: Add to calendar
                  },
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Add to Calendar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Date Card ───────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime date;
  final Color color;
  final VoidCallback onEdit;

  const _DateCard({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                Text(
                  DateUtils2.formatDateTime(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Progress Card ───────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final Task task;
  final int totalDays;

  const _ProgressCard({required this.task, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final elapsed = now.difference(task.startTime).inDays;
    final progress = totalDays > 0 ? (elapsed / totalDays).clamp(0.0, 1.0) : 0.0;
    final remaining = totalDays - elapsed;

    Color progressColor;
    String statusText;

    if (now.isBefore(task.startTime)) {
      progressColor = AppColors.textTertiary;
      statusText = 'Not started — begins ${DateUtils2.timeAgo(task.startTime)}';
    } else if (now.isAfter(task.endTime)) {
      progressColor = const Color(0xFFD63031);
      statusText = 'Overdue by ${now.difference(task.endTime).inDays} days';
    } else {
      progressColor = const Color(0xFF00B894);
      statusText = '$remaining days remaining';
    }

    return Container(
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
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
              const Spacer(),
              Text(
                statusText,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
