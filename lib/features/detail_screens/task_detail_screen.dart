import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/task_provider.dart';
import '../../shared/widgets/badges/status_badge.dart';
import '../../shared/widgets/feedback/feedback_widgets.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Task not found',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.taskName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  StatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                task.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Info cards
              _InfoRow(icon: Icons.schedule, label: 'Timeline',
                value: DateUtils2.dateRange(task.startTime, task.endTime)),
              _InfoRow(icon: Icons.timer, label: 'Duration',
                value: '${task.durationDays} days'),
              if (task.guidePrice != null)
                _InfoRow(icon: Icons.auto_awesome, label: 'AI Guide Price',
                  value: CurrencyUtils.formatPrice(task.guidePrice!)),
              if (task.acceptedQuote != null)
                _InfoRow(icon: Icons.check_circle, label: 'Accepted Quote',
                  value: '${CurrencyUtils.formatPrice(task.acceptedQuote!.amount)} — ${task.acceptedQuote!.contractorName}'),
              const SizedBox(height: AppSpacing.lg),

              // Quotes section
              if (task.quotes.isNotEmpty) ...[
                Text('Quotes (${task.quotes.length})',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                ...task.quotes.map((quote) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(quote.contractorName,
                                style: Theme.of(context).textTheme.titleMedium)),
                            Text(CurrencyUtils.formatPrice(quote.amount),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(quote.description,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Participants
              if (task.participants.isNotEmpty) ...[
                Text('Participants (${task.participants.length})',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                ...task.participants.map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(p.role.icon, color: AppColors.primary, size: 18),
                  ),
                  title: Text(p.name),
                  subtitle: Text(p.role.label),
                  trailing: const Icon(Icons.chat_bubble_outline, size: 20),
                )),
              ],

              // Action buttons
              const SizedBox(height: AppSpacing.lg),
              if (task.actionSpace.isNotEmpty) ...[
                Text('Actions', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: task.actionSpace.map((action) {
                    return ActionChip(
                      label: Text(action.replaceAll('_', ' ')),
                      onPressed: () {
                        // TODO: handle action
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
