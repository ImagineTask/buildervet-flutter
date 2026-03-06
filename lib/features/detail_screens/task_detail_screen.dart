import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../models/task.dart';
import '../../models/task_event.dart';
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
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const EmptyState(icon: Icons.search_off, title: 'Task not found');
          }
          return _TaskDetailContent(task: task);
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

// ─── Main Content ────────────────────────────────────────

class _TaskDetailContent extends StatelessWidget {
  final Task task;

  const _TaskDetailContent({required this.task});

  @override
  Widget build(BuildContext context) {
    final hasQuotes = task.quotes.isNotEmpty;
    final hasParticipants = task.participants.isNotEmpty;
    final hasPhotos = (task.metadata['photos'] as List?)?.isNotEmpty == true;
    final hasInvoice = task.metadata['invoice'] != null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task.taskName, style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(status: task.status),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          task.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Action Sections ───────────────────────────────

        // Timeline
        _TappableSection(
          icon: Icons.calendar_month,
          iconColor: const Color(0xFF45B7D1),
          title: 'Timeline',
          onTap: () => context.push('/actions/task-schedule/${task.taskId}'),
          child: Column(
            children: [
              _DetailRow(label: 'Start', value: DateUtils2.formatDateTime(task.startTime)),
              _DetailRow(label: 'End', value: DateUtils2.formatDateTime(task.endTime)),
              _DetailRow(label: 'Duration', value: '${task.durationDays} days', valueColor: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Budget & Quotes
        _TappableSection(
          icon: Icons.request_quote,
          iconColor: const Color(0xFFFF6B6B),
          title: 'Budget & Quotes',
          trailing: hasQuotes ? _CountBadge(count: task.quotes.length, color: const Color(0xFFFF6B6B)) : null,
          onTap: () => context.push('/actions/task-quote/${task.taskId}'),
          child: Column(
            children: [
              if (task.guidePrice != null)
                _DetailRow(label: 'AI Guide Price', value: CurrencyUtils.formatPrice(task.guidePrice!)),
              if (task.acceptedQuote != null)
                _DetailRow(
                  label: 'Accepted',
                  value: '${CurrencyUtils.formatPrice(task.acceptedQuote!.amount)} — ${task.acceptedQuote!.contractorName}',
                  valueColor: const Color(0xFF00B894),
                )
              else if (hasQuotes)
                _DetailRow(label: 'Quotes', value: '${task.pendingQuoteCount} pending', valueColor: const Color(0xFFFECA57))
              else
                _DetailRow(label: 'Quotes', value: 'No quotes yet', valueColor: AppColors.textTertiary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // People
        _TappableSection(
          icon: Icons.people,
          iconColor: const Color(0xFF6366F1),
          title: 'People',
          trailing: hasParticipants ? _CountBadge(count: task.participants.length, color: const Color(0xFF6366F1)) : null,
          onTap: () => context.push('/actions/task-schedule/${task.taskId}'),
          child: hasParticipants
              ? Column(
                  children: task.participants.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(p.role.icon, color: AppColors.primary, size: 14),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 14))),
                        Text(p.role.label, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ),
                  )).toList(),
                )
              : Text('No one assigned yet', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Photos
        _TappableSection(
          icon: Icons.camera_alt,
          iconColor: const Color(0xFFFECA57),
          title: 'Photos',
          trailing: hasPhotos ? _CountBadge(count: (task.metadata['photos'] as List?)?.length ?? 0, color: const Color(0xFFE17055)) : null,
          onTap: () {
            if (task.isProject) {
              context.push('/actions/project-photo/${task.taskId}');
            }
          },
          child: Text(
            hasPhotos ? 'Tap to view and upload photos' : 'No photos yet — tap to upload',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Invoice
        _TappableSection(
          icon: Icons.receipt_long,
          iconColor: const Color(0xFF6C5CE7),
          title: 'Invoice',
          onTap: () => context.push('/actions/task-invoice/${task.taskId}'),
          child: _DetailRow(
            label: 'Status',
            value: hasInvoice
                ? (task.metadata['invoice']['status'] as String? ?? 'Draft').toUpperCase()
                : 'Not created',
            valueColor: hasInvoice ? const Color(0xFF6C5CE7) : AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── History Timeline ──────────────────────────────
        if (task.events.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('History', style: Theme.of(context).textTheme.headlineSmall),
              ),
              Text(
                '${task.events.length} events',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HistoryTimeline(events: task.eventsChronological),
        ],

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─── History Timeline ────────────────────────────────────

class _HistoryTimeline extends StatefulWidget {
  final List<TaskEvent> events;

  const _HistoryTimeline({required this.events});

  @override
  State<_HistoryTimeline> createState() => _HistoryTimelineState();
}

class _HistoryTimelineState extends State<_HistoryTimeline> {
  static const _collapsedCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final showToggle = events.length > _collapsedCount;
    final displayEvents = _expanded ? events : events.take(_collapsedCount).toList();

    return Column(
      children: [
        ...List.generate(displayEvents.length, (index) {
          final event = displayEvents[index];
          final isLast = index == displayEvents.length - 1 && (_expanded || !showToggle);

          return _HistoryEventTile(event: event, isLast: isLast);
        }),

        if (showToggle)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded ? 'Show less' : 'Show all ${events.length} events',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryEventTile extends StatelessWidget {
  final TaskEvent event;
  final bool isLast;

  const _HistoryEventTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: event.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 13, color: event.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.textTertiary.withOpacity(0.12),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        event.actorName,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateUtils2.timeAgo(event.timestamp),
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tappable Section Card ───────────────────────────────

class _TappableSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;
  final Widget child;

  const _TappableSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                if (trailing != null) trailing!,
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(padding: const EdgeInsets.only(left: 36), child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Count Badge ─────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Detail Row ──────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? AppColors.textPrimary),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}