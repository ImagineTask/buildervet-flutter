import 'package:flutter/material.dart';
import '../../Home/models/task_model.dart';

class TaskAssignedTypeCard extends StatelessWidget {
  final TaskModel task;

  const TaskAssignedTypeCard({super.key, required this.task});

  Color get _statusColor {
    switch (task.status) {
      case 'pending_acceptance':
        return const Color(0xFFFFB347);
      case 'active':
        return const Color(0xFF6C63FF);
      case 'negotiating':
        return const Color(0xFF4ECDC4);
      case 'done':
        return const Color(0xFF43C59E);
      case 'denied':
        return const Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (task.status) {
      case 'pending_acceptance':
        return 'Awaiting';
      case 'active':
        return 'Active';
      case 'negotiating':
        return 'Negotiating';
      case 'done':
        return 'Done';
      case 'denied':
        return 'Denied';
      default:
        return task.status;
    }
  }

  int get _scheduledDays {
    final dates = task.metadata['scheduledDates'];
    if (dates == null) return 0;
    return (dates as List).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                      color: _statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.taskName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Description
            if (task.description.isNotEmpty)
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            const SizedBox(height: 12),

            // Info row
            Row(
              children: [
                if (_scheduledDays > 0) ...[
                  _infoChip(Icons.calendar_today_outlined,
                      '$_scheduledDays day${_scheduledDays > 1 ? 's' : ''}'),
                  const SizedBox(width: 8),
                ],
                if (task.contractorType != null) ...[
                  _infoChip(
                      Icons.work_outline, task.contractorType!),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (task.guidePrice > 0)
                  Row(
                    children: [
                      Icon(Icons.attach_money,
                          size: 13, color: Colors.grey[400]),
                      Text(
                        '£${task.guidePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}