import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskScheduleSection extends ConsumerWidget {
  const TaskScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Upcoming Tasks'),
        tasksAsync.when(
          data: (tasks) {
            final upcoming = tasks
                .where((t) => !t.isProject && t.endTime.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

            if (upcoming.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available,
                title: 'No upcoming tasks',
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcoming.length,
              itemBuilder: (context, index) {
                final task = upcoming[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  leading: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: task.status.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    task.taskName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    DateUtils2.dateRange(task.startTime, task.endTime),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: StatusBadge(status: task.status),
                );
              },
            );
          },
          loading: () => const LoadingIndicator(),
          error: (err, _) => ErrorView(message: err.toString()),
        ),
      ],
    );
  }
}
