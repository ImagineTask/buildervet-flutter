import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../models/enums/task_status.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskProgressScreen extends ConsumerWidget {
  final String taskId;

  const TaskProgressScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const ErrorView(message: 'Task not found');
          }
          return _ProgressContent(task: task);
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

/// The workflow steps for a standard renovation task.
/// Each step maps to a real milestone in the renovation process.
class _WorkflowStep {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? actionRoute; // where tapping this step navigates

  const _WorkflowStep({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.actionRoute,
  });
}

enum _StepState { completed, current, upcoming }

class _ProgressContent extends StatelessWidget {
  final Task task;

  const _ProgressContent({required this.task});

  /// Determine the workflow steps and which one is current
  /// based on the task's actual data state.
  List<_WorkflowStep> get _steps => const [
    _WorkflowStep(
      key: 'created',
      title: 'Task Created',
      description: 'Task has been defined with scope and requirements',
      icon: Icons.add_circle_outline,
      color: Color(0xFF6366F1),
    ),
    _WorkflowStep(
      key: 'quoted',
      title: 'Quotes Received',
      description: 'Contractors have submitted their quotes',
      icon: Icons.request_quote,
      color: Color(0xFFFF6B6B),
      actionRoute: 'quote',
    ),
    _WorkflowStep(
      key: 'accepted',
      title: 'Quote Accepted',
      description: 'A quote has been reviewed and accepted',
      icon: Icons.check_circle_outline,
      color: Color(0xFF00B894),
      actionRoute: 'quote',
    ),
    _WorkflowStep(
      key: 'scheduled',
      title: 'Work Scheduled',
      description: 'Contractor assigned and dates confirmed',
      icon: Icons.calendar_month,
      color: Color(0xFF45B7D1),
      actionRoute: 'schedule',
    ),
    _WorkflowStep(
      key: 'in_progress',
      title: 'Work In Progress',
      description: 'Contractor is on site doing the work',
      icon: Icons.construction,
      color: Color(0xFFFECA57),
    ),
    _WorkflowStep(
      key: 'inspection',
      title: 'Inspection',
      description: 'Work reviewed and signed off by homeowner',
      icon: Icons.verified_outlined,
      color: Color(0xFFE17055),
    ),
    _WorkflowStep(
      key: 'invoiced',
      title: 'Invoiced',
      description: 'Invoice issued for completed work',
      icon: Icons.receipt_long,
      color: Color(0xFF6C5CE7),
      actionRoute: 'invoice',
    ),
    _WorkflowStep(
      key: 'completed',
      title: 'Completed',
      description: 'Payment received and task closed',
      icon: Icons.celebration,
      color: Color(0xFF00B894),
    ),
  ];

  /// Determine which step the task is currently on based on its real data
  int _currentStepIndex() {
    // Completed task
    if (task.status == TaskStatus.completed) return 7;

    // Has invoice
    if (task.metadata['invoice'] != null) {
      final invoiceStatus = task.metadata['invoice']['status'] as String?;
      if (invoiceStatus == 'paid') return 7;
      return 6;
    }

    // In progress with work happening
    if (task.status == TaskStatus.inProgress) return 4;

    // Has participants assigned (scheduled)
    if (task.participants.isNotEmpty) return 3;

    // Has accepted quote
    if (task.acceptedQuote != null) return 2;

    // Has quotes but none accepted
    if (task.quotes.isNotEmpty) return 1;

    // Just created
    return 0;
  }

  _StepState _getStepState(int stepIndex, int currentIndex) {
    if (stepIndex < currentIndex) return _StepState.completed;
    if (stepIndex == currentIndex) return _StepState.current;
    return _StepState.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final currentIndex = _currentStepIndex();
    final progress = steps.isNotEmpty ? (currentIndex / (steps.length - 1)).clamp(0.0, 1.0) : 0.0;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.taskName, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Step ${currentIndex + 1} of ${steps.length}',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Circular progress
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation(steps[currentIndex].color),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: steps[currentIndex].color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Current step highlight
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: steps[currentIndex].color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: steps[currentIndex].color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: steps[currentIndex].color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(steps[currentIndex].icon, color: steps[currentIndex].color, size: 24),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Step',
                        style: TextStyle(fontSize: 11, color: steps[currentIndex].color, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        steps[currentIndex].title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: steps[currentIndex].color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[currentIndex].description,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Step list
          Text('All Steps', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),

          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final state = _getStepState(index, currentIndex);
            final isLast = index == steps.length - 1;

            return _StepTile(
              step: step,
              state: state,
              isLast: isLast,
              taskId: task.taskId,
              onTap: step.actionRoute != null
                  ? () {
                      switch (step.actionRoute) {
                        case 'quote':
                          context.push('/actions/task-quote/${task.taskId}');
                          break;
                        case 'schedule':
                          context.push('/actions/task-schedule/${task.taskId}');
                          break;
                        case 'invoice':
                          context.push('/actions/task-invoice/${task.taskId}');
                          break;
                      }
                    }
                  : null,
            );
          }),

          const SizedBox(height: AppSpacing.lg),

          // Advance step button (for the current step)
          if (currentIndex < steps.length - 1)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // TODO: Advance to next step via provider
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Advanced to: ${steps[currentIndex + 1].title}'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text('Mark as ${steps[currentIndex + 1].title}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: steps[currentIndex + 1].color,
                ),
              ),
            ),

          if (currentIndex == steps.length - 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF00B894).withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: const Color(0xFF00B894).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.celebration, size: 36, color: Color(0xFF00B894)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Task Complete!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF00B894)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All steps have been finished',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step Tile ───────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final _WorkflowStep step;
  final _StepState state;
  final bool isLast;
  final String taskId;
  final VoidCallback? onTap;

  const _StepTile({
    required this.step,
    required this.state,
    required this.isLast,
    required this.taskId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = state == _StepState.completed;
    final isCurrent = state == _StepState.current;
    final isUpcoming = state == _StepState.upcoming;

    final dotColor = isCompleted
        ? step.color
        : isCurrent
            ? step.color
            : AppColors.textTertiary.withOpacity(0.3);

    final lineColor = isCompleted
        ? step.color.withOpacity(0.4)
        : AppColors.textTertiary.withOpacity(0.15);

    final textColor = isUpcoming ? AppColors.textTertiary : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline column
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Dot
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCurrent ? dotColor.withOpacity(0.15) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: dotColor, width: isCurrent ? 3 : 2),
                    ),
                    child: isCompleted
                        ? Icon(Icons.check, size: 14, color: dotColor)
                        : isCurrent
                            ? Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                              )
                            : null,
                  ),
                  // Connecting line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: lineColor,
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(step.icon, size: 18, color: isUpcoming ? AppColors.textTertiary : step.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (onTap != null && !isUpcoming)
                          Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isUpcoming ? AppColors.textTertiary.withOpacity(0.6) : AppColors.textSecondary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: step.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          'CURRENT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: step.color, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
