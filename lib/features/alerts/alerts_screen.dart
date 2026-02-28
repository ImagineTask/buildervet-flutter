import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/alert.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Alerts',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // TODO: Mark all read
                },
                child: const Text('Mark all read'),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              _mockAlerts.map((a) => _AlertCard(alert: a)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Mock alerts
final _mockAlerts = [
  Alert(
    id: 'alert-001',
    title: 'New quote received',
    body: 'AquaFix Plumbing submitted a quote of £1,950 for Plumbing Rough-In',
    taskId: 'task-003',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    type: AlertType.quoteReceived,
  ),
  Alert(
    id: 'alert-002',
    title: 'Task started',
    body: 'Dave Wilson has started Electrical Rewiring',
    taskId: 'task-002',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    type: AlertType.taskUpdated,
  ),
  Alert(
    id: 'alert-003',
    title: 'Task completed',
    body: 'Cabinet Demolition has been marked as completed',
    taskId: 'task-001',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
    type: AlertType.taskCompleted,
  ),
  Alert(
    id: 'alert-004',
    title: 'New message',
    body: 'James Smith sent you a message about Kitchen Renovation',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
    type: AlertType.messageReceived,
  ),
  Alert(
    id: 'alert-005',
    title: 'New quote received',
    body: 'QuickPaint Co submitted a quote of £650 for Living Room Painting',
    taskId: 'task-012',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
    type: AlertType.quoteReceived,
  ),
  Alert(
    id: 'alert-006',
    title: 'Reminder',
    body: 'Cabinet installation materials need to be confirmed this week',
    taskId: 'task-004',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    isRead: true,
    type: AlertType.reminder,
  ),
];

class _AlertCard extends StatelessWidget {
  final Alert alert;
  const _AlertCard({required this.alert});

  IconData _iconForType(AlertType type) {
    switch (type) {
      case AlertType.quoteReceived:
        return Icons.request_quote;
      case AlertType.taskUpdated:
        return Icons.update;
      case AlertType.taskCompleted:
        return Icons.check_circle;
      case AlertType.messageReceived:
        return Icons.chat;
      case AlertType.paymentDue:
        return Icons.payment;
      case AlertType.reminder:
        return Icons.alarm;
    }
  }

  Color _colorForType(AlertType type) {
    switch (type) {
      case AlertType.quoteReceived:
        return AppColors.accent;
      case AlertType.taskUpdated:
        return AppColors.info;
      case AlertType.taskCompleted:
        return AppColors.success;
      case AlertType.messageReceived:
        return AppColors.primary;
      case AlertType.paymentDue:
        return AppColors.error;
      case AlertType.reminder:
        return AppColors.secondary;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(alert.type);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: alert.isRead ? null : color.withOpacity(0.03),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconForType(alert.type), color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                alert.title,
                style: TextStyle(
                  fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            Text(
              _timeAgo(alert.createdAt),
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            alert.body,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () {
          // TODO: Navigate to related task/conversation
        },
      ),
    );
  }
}
