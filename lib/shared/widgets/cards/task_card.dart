import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../badges/status_badge.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.taskName,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                task.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Bottom row: date range + price + participants count
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    DateUtils2.dateRange(task.startTime, task.endTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                  const Spacer(),
                  if (task.guidePrice != null) ...[
                    Text(
                      CurrencyUtils.formatPriceCompact(task.guidePrice!),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                  if (task.participants.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 2),
                    Text(
                      '${task.participants.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ],
              ),

              // Quotes indicator
              if (task.pendingQuoteCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  ),
                  child: Text(
                    '${task.pendingQuoteCount} quote(s) awaiting review',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
