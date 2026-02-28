import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../../shared/widgets/cards/task_card.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskListSection extends ConsumerWidget {
  const TaskListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Active Tasks',
          actionText: 'See all',
          onAction: () {
            // TODO: Navigate to full task list
          },
        ),
        tasksAsync.when(
          data: (tasks) {
            // Show non-project tasks that are active
            final activeTasks = tasks
                .where((t) =>
                    !t.isProject &&
                    (t.status.name == 'inProgress' || t.status.name == 'pending'))
                .take(5)
                .toList();

            if (activeTasks.isEmpty) {
              return const EmptyState(
                icon: Icons.task_alt,
                title: 'No active tasks',
                subtitle: 'Your active tasks will appear here',
              );
            }

            return Column(
              children: activeTasks
                  .map((task) => TaskCard(
                        task: task,
                        onTap: () {
                          context.pushNamed(
                            RouteNames.taskDetail,
                            pathParameters: {'taskId': task.taskId},
                          );
                        },
                      ))
                  .toList(),
            );
          },
          loading: () => const LoadingIndicator(),
          error: (err, _) => ErrorView(message: err.toString()),
        ),
      ],
    );
  }
}
