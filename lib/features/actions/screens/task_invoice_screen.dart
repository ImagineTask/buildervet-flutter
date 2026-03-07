import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskInvoiceScreen extends ConsumerWidget {
  final String taskId;

  const TaskInvoiceScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
      ),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const ErrorView(message: 'Task not found');
          }
          return _InvoiceContent(task: task);
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

class _InvoiceContent extends StatelessWidget {
  final Task task;

  const _InvoiceContent({required this.task});

  @override
  Widget build(BuildContext context) {
    // Determine invoice state from task metadata
    // TODO: Replace with real Invoice model when backend is ready
    final invoiceData = task.metadata['invoice'] as Map<String, dynamic>?;
    final invoiceStatus = invoiceData?['status'] as String? ?? 'none';

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
                StatusBadge(status: task.status),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Invoice status card
          _InvoiceStatusCard(status: invoiceStatus),
          const SizedBox(height: AppSpacing.lg),

          // Cost breakdown
          Text(
            'Cost Breakdown',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CostBreakdown(task: task),
          const SizedBox(height: AppSpacing.lg),

          // Actions based on state
          if (invoiceStatus == 'none')
            _NoInvoiceActions()
          else if (invoiceStatus == 'draft')
            _DraftInvoiceActions()
          else if (invoiceStatus == 'issued')
            _IssuedInvoiceActions()
          else if (invoiceStatus == 'paid')
            _PaidInvoiceView(),
        ],
      ),
    );
  }
}

// ─── Invoice Status Card ─────────────────────────────────

class _InvoiceStatusCard extends StatelessWidget {
  final String status;

  const _InvoiceStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    String subtitle;
    Color color;

    switch (status) {
      case 'draft':
        icon = Icons.edit_note;
        title = 'Draft Invoice';
        subtitle = 'Invoice is being prepared. Review and send when ready.';
        color = const Color(0xFFFFA502);
        break;
      case 'issued':
        icon = Icons.send;
        title = 'Invoice Sent';
        subtitle = 'Waiting for payment from the client.';
        color = const Color(0xFF45B7D1);
        break;
      case 'paid':
        icon = Icons.check_circle;
        title = 'Paid';
        subtitle = 'This invoice has been paid in full.';
        color = const Color(0xFF00B894);
        break;
      default:
        icon = Icons.receipt_long;
        title = 'No Invoice';
        subtitle = 'No invoice has been created for this task yet.';
        color = AppColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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

// ─── Cost Breakdown ──────────────────────────────────────

class _CostBreakdown extends StatelessWidget {
  final Task task;

  const _CostBreakdown({required this.task});

  @override
  Widget build(BuildContext context) {
    final accepted = task.acceptedQuote;
    final guide = task.guidePrice;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (guide != null)
            _CostRow(
              label: 'Guide Price',
              amount: CurrencyUtils.formatPrice(guide),
              isSubtle: true,
            ),
          if (accepted != null) ...[
            if (guide != null) const Divider(height: AppSpacing.md),
            _CostRow(
              label: 'Accepted Quote (${accepted.contractorName})',
              amount: CurrencyUtils.formatPrice(accepted.amount),
            ),
          ],
          if (accepted == null && guide == null)
            Center(
              child: Text(
                'No pricing information available',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ),
          if (accepted != null) ...[
            const Divider(height: AppSpacing.md),
            _CostRow(
              label: 'Total',
              amount: CurrencyUtils.formatPrice(accepted.amount),
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isSubtle;
  final bool isBold;

  const _CostRow({
    required this.label,
    required this.amount,
    this.isSubtle = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isSubtle ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isSubtle ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action States ───────────────────────────────────────

class _NoInvoiceActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          // TODO: Create invoice
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Invoice'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

class _DraftInvoiceActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Edit draft
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              // TODO: Send invoice
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send Invoice'),
          ),
        ),
      ],
    );
  }
}

class _IssuedInvoiceActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              // TODO: Mark as paid
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Mark as Paid'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Send reminder
            },
            icon: const Icon(Icons.notifications_active, size: 18),
            label: const Text('Send Payment Reminder'),
          ),
        ),
      ],
    );
  }
}

class _PaidInvoiceView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF00B894).withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            size: 48,
            color: const Color(0xFF00B894),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Payment Complete',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00B894),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Download receipt
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Receipt'),
            ),
          ),
        ],
      ),
    );
  }
}
