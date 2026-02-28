import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/inputs/app_search_bar.dart';
import '../../shared/widgets/layout/section_header.dart';
import 'sections/people_list_section.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Network',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () {
                  // TODO: Add person flow
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                const AppSearchBar(hintText: 'Search people...'),
                const SizedBox(height: AppSpacing.md),
                const PeopleListSection(),
                // Future sections:
                // RecommendedContractorsSection(),
                // RecentlyContactedSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
