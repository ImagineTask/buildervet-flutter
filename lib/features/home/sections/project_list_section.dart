import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/routing/route_names.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../../shared/widgets/cards/project_card.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class ProjectListSection extends ConsumerWidget {
  const ProjectListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Projects',
          actionText: 'See all',
          onAction: () {
            // TODO: Navigate to full project list
          },
        ),
        projectsAsync.when(
          data: (projects) {
            if (projects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('No projects yet'),
              );
            }
            return SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: AppSpacing.md),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ProjectCard(
                    project: project,
                    subtaskCount: 0, // TODO: count from provider
                    onTap: () {
                      context.pushNamed(
                        RouteNames.projectDetail,
                        pathParameters: {'projectId': project.taskId},
                      );
                    },
                  );
                },
              ),
            );
          },
          loading: () => const LoadingIndicator(),
          error: (err, _) => ErrorView(message: err.toString()),
        ),
      ],
    );
  }
}
