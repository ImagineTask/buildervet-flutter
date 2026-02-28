import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'sections/search_section.dart';
import 'sections/project_task_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Greeting header
          SliverAppBar(
            floating: true,
            title: Text(
              _greeting(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            actions: [
              GestureDetector(
                onTap: () {
                  // TODO: Profile
                },
                child: Container(
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.person, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          // Sections
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                const SearchSection(),
                const SizedBox(height: AppSpacing.md),

                // Combined: tab toggle → carousel → contextual actions
                const ProjectTaskSection(),

                const SizedBox(height: AppSpacing.xl),
                // Future sections go here:
                // RecentActivitySection(),
                // AiInsightsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }
}