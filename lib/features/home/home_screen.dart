import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import 'sections/search_section.dart';
import 'sections/project_list_section.dart';
import 'sections/task_list_section.dart';
import 'sections/action_area_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            title: Text(
              'BuilderVet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  // TODO: Create new task/project
                },
              ),
              IconButton(
                icon: const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.person, size: 16),
                ),
                onPressed: () {
                  // TODO: Profile
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Sections — add/remove/reorder these as needed
          const SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: AppSpacing.sm),
                SearchSection(),
                SizedBox(height: AppSpacing.md),
                ProjectListSection(),
                SizedBox(height: AppSpacing.sm),
                TaskListSection(),
                SizedBox(height: AppSpacing.sm),
                ActionAreaSection(),
                SizedBox(height: AppSpacing.xl),
                // Future sections go here:
                // RecentQuotesSection(),
                // AiInsightsSection(),
                // UpcomingDeadlinesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
