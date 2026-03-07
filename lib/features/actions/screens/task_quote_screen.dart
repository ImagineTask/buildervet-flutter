import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../models/quote.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskQuoteScreen extends ConsumerWidget {
  final String taskId;

  const TaskQuoteScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotes'),
      ),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const ErrorView(message: 'Task not found');
          }
          return _QuoteContent(task: task);
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

class _QuoteContent extends StatelessWidget {
  final Task task;

  const _QuoteContent({required this.task});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task header
          _TaskHeader(task: task),
          const SizedBox(height: AppSpacing.lg),

          // Guide price
          if (task.guidePrice != null) ...[
            _InfoCard(
              icon: Icons.lightbulb_outline,
              label: 'AI Guide Price',
              value: CurrencyUtils.formatPrice(task.guidePrice!),
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Quote summary
          Row(
            children: [
              Text(
                'Quotes (${task.quotes.length})',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  // TODO: Request new quote
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Request'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Quote list
          if (task.quotes.isEmpty)
            _EmptyQuotes()
          else
            ...task.quotes.map((quote) => _QuoteCard(
                  quote: quote,
                  guidePrice: task.guidePrice,
                )),
        ],
      ),
    );
  }
}

// ─── Task Header ─────────────────────────────────────────

class _TaskHeader extends StatelessWidget {
  final Task task;
  const _TaskHeader({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(
                  task.taskName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(status: task.status),
        ],
      ),
    );
  }
}

// ─── Info Card ───────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Quotes ────────────────────────────────────────

class _EmptyQuotes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.request_quote, size: 48, color: AppColors.textTertiary.withOpacity(0.5)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No quotes yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Request quotes from contractors to compare prices',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Quote Card ──────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final Quote quote;
  final double? guidePrice;

  const _QuoteCard({required this.quote, this.guidePrice});

  @override
  Widget build(BuildContext context) {
    // Compare to guide price
    String? comparison;
    Color? comparisonColor;
    if (guidePrice != null && guidePrice! > 0) {
      final diff = quote.amount - guidePrice!;
      final pct = (diff / guidePrice! * 100).round();
      if (pct > 0) {
        comparison = '${pct}% above guide';
        comparisonColor = const Color(0xFFE17055);
      } else if (pct < 0) {
        comparison = '${pct.abs()}% below guide';
        comparisonColor = const Color(0xFF00B894);
      } else {
        comparison = 'At guide price';
        comparisonColor = AppColors.primary;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: quote.status.name == 'accepted'
              ? const Color(0xFF00B894)
              : AppColors.border,
          width: quote.status.name == 'accepted' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contractor + status
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  quote.contractorName.isNotEmpty
                      ? quote.contractorName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.contractorName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Submitted ${DateUtils2.timeAgo(quote.submittedAt)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              _QuoteStatusBadge(status: quote.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Description
          if (quote.description.isNotEmpty) ...[
            Text(
              quote.description,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Amount + comparison
          Row(
            children: [
              Text(
                CurrencyUtils.formatPrice(quote.amount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (comparison != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: comparisonColor!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  ),
                  child: Text(
                    comparison,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: comparisonColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action buttons
          if (quote.status.name == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Reject quote
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD63031),
                      side: const BorderSide(color: Color(0xFFD63031)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: Accept quote
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuoteStatusBadge extends StatelessWidget {
  final dynamic status;
  const _QuoteStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusName = status.toString().split('.').last;
    Color color;
    String label;

    switch (statusName) {
      case 'accepted':
        color = const Color(0xFF00B894);
        label = 'Accepted';
        break;
      case 'rejected':
        color = const Color(0xFFD63031);
        label = 'Rejected';
        break;
      default:
        color = const Color(0xFFFFA502);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
