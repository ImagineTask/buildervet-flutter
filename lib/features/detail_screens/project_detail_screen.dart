import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/task_provider.dart';
import '../../shared/widgets/badges/status_badge.dart';
import '../../shared/widgets/cards/task_card.dart';
import '../../shared/widgets/feedback/feedback_widgets.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(taskByIdProvider(projectId));
    final subtasksAsync = ref.watch(projectTasksProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
        ],
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const EmptyState(
              icon: Icons.folder_off,
              title: 'Project not found',
            );
          }

          return ListView(
            children: [
              // Project header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.taskName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        StatusBadge(status: project.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      project.description,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _Stat(
                          label: 'Guide Price',
                          value: project.guidePrice != null
                              ? CurrencyUtils.formatPrice(project.guidePrice!)
                              : 'N/A',
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _Stat(
                          label: 'Timeline',
                          value: DateUtils2.dateRange(project.startTime, project.endTime),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _Stat(
                          label: 'Duration',
                          value: '${project.durationDays} days',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Subtasks
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text('Tasks',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              subtasksAsync.when(
                data: (subtasks) {
                  if (subtasks.isEmpty) {
                    return const EmptyState(
                      icon: Icons.task_alt,
                      title: 'No tasks yet',
                      subtitle: 'Add tasks to this project',
                      actionText: 'Add Task',
                    );
                  }
                  return Column(
                    children: subtasks
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
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add task to project
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
