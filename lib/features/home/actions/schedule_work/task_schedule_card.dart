import 'package:flutter/material.dart';
import '../../models/task_model.dart';

class TaskScheduleCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const TaskScheduleCard({super.key, required this.task, required this.onTap});

  bool get isAssigned => task.assignedBuilderIds.isNotEmpty;

  bool get isScheduled =>
      task.metadata['scheduledDates'] != null &&
      (task.metadata['scheduledDates'] as List).isNotEmpty;

  bool get needsAttention => !isAssigned || !isScheduled;

  int get scheduledDaysCount =>
      isScheduled ? (task.metadata['scheduledDates'] as List).length : 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task name + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.taskName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(task.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(task.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Assigned builders
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  isAssigned
                      ? Text(
                          '${task.assignedBuilderIds.length} builder(s) assigned',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        )
                      : const Text(
                          'No builder assigned',
                          style: TextStyle(fontSize: 13, color: Colors.red),
                        ),
                ],
              ),
              const SizedBox(height: 6),

              // Schedule
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  isScheduled
                      ? Text(
                          '$scheduledDaysCount working day${scheduledDaysCount > 1 ? 's' : ''} scheduled',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        )
                      : const Text(
                          'Not scheduled',
                          style: TextStyle(fontSize: 13, color: Colors.red),
                        ),
                ],
              ),
              const SizedBox(height: 6),

              // Fee
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  task.guidePrice > 0
                      ? Text(
                          '\$${task.guidePrice.toStringAsFixed(0)} agreed fee',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        )
                      : const Text(
                          'No fee set',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                ],
              ),

              // Warning banner
              if (needsAttention) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 15, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Needs to be scheduled & assigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'done':
        return Colors.blue;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}