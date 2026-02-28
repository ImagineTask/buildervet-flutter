import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import 'sections/calendar_view_section.dart';
import 'sections/task_schedule_section.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Calendar',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.today),
                onPressed: () {
                  // TODO: Jump to today
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SliverToBoxAdapter(
            child: Column(
              children: [
                CalendarViewSection(),
                SizedBox(height: AppSpacing.md),
                TaskScheduleSection(),
                // Future sections:
                // DeadlineSection(),
                // MilestoneSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
