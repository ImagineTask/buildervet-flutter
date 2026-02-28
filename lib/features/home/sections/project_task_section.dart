import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/routing/route_names.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';
import 'card_carousel_section.dart';
import 'contextual_action_section.dart';

class ProjectTaskSection extends ConsumerWidget {
  const ProjectTaskSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(homeTabProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _TabToggle(
            selectedTab: selectedTab,
            onTabChanged: (index) {
              ref.read(homeTabProvider.notifier).state = index;
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Section title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            selectedTab == 0 ? 'Project' : 'Task',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Carousel + Actions
        if (selectedTab == 0)
          const _ProjectTab()
        else
          const _TaskTab(),
      ],
    );
  }
}

// ─── Tab Toggle ──────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _TabToggle({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabButton(
            icon: Icons.folder_outlined,
            label: 'Projects',
            isSelected: selectedTab == 0,
            onTap: () => onTabChanged(0),
          ),
          _TabButton(
            icon: Icons.check_circle_outline,
            label: 'Tasks',
            isSelected: selectedTab == 1,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Project Tab ─────────────────────────────────────────

class _ProjectTab extends ConsumerWidget {
  const _ProjectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    return projectsAsync.when(
      data: (projects) {
        // Find the selected task object
        Task? selectedTask;
        if (selectedId != null) {
          try {
            selectedTask = projects.firstWhere((t) => t.taskId == selectedId);
          } catch (_) {
            selectedTask = null;
          }
        }

        return Column(
          children: [
            CardCarouselSection(
              items: projects,
              selectedId: selectedId,
              onSelect: (id) {
                ref.read(selectedProjectIdProvider.notifier).state = id;
              },
              onSeeAll: () {
                context.pushNamed(RouteNames.seeAllProjects);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ContextualActionSection(selectedTask: selectedTask),
          ],
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, _) => ErrorView(message: err.toString()),
    );
  }
}

// ─── Task Tab ────────────────────────────────────────────

class _TaskTab extends ConsumerWidget {
  const _TaskTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    final selectedId = ref.watch(selectedTaskIdProvider);

    return tasksAsync.when(
      data: (tasks) {
        final normalTasks = tasks.where((t) => !t.isProject).toList();

        // Find the selected task object
        Task? selectedTask;
        if (selectedId != null) {
          try {
            selectedTask = normalTasks.firstWhere((t) => t.taskId == selectedId);
          } catch (_) {
            selectedTask = null;
          }
        }

        return Column(
          children: [
            CardCarouselSection(
              items: normalTasks,
              selectedId: selectedId,
              onSelect: (id) {
                ref.read(selectedTaskIdProvider.notifier).state = id;
              },
              onSeeAll: () {
                context.pushNamed(RouteNames.seeAllTasks);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ContextualActionSection(selectedTask: selectedTask),
          ],
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, _) => ErrorView(message: err.toString()),
    );
  }
}