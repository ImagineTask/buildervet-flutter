import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import 'owner_task_card.dart';

class ViewTasksPage extends StatelessWidget {
  final TaskModel project;

  const ViewTasksPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          project.taskName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('parentTaskId', isEqualTo: project.taskId)
            .where('taskType', isEqualTo: 'task')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.grey)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState();
          }

          // Sort: negotiating first (until decision made), then by taskOrder
          final tasks = snapshot.data!.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList()
            ..sort((a, b) {
              final aIsNegotiating = a.status == 'negotiating' ? 0 : 1;
              final bIsNegotiating = b.status == 'negotiating' ? 0 : 1;
              if (aIsNegotiating != bIsNegotiating) {
                return aIsNegotiating.compareTo(bIsNegotiating);
              }
              // Within same group, sort by taskOrder
              return (a.metadata['taskOrder'] ?? 0)
                  .compareTo(b.metadata['taskOrder'] ?? 0);
            });

          // Count negotiating tasks for header badge
          final negotiatingCount =
              tasks.where((t) => t.status == 'negotiating').length;

          return Column(
            children: [
              // Summary bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _summaryChip(
                      '${tasks.length} Tasks',
                      const Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 8),
                    if (negotiatingCount > 0)
                      _summaryChip(
                        '$negotiatingCount Negotiating',
                        const Color(0xFF4ECDC4),
                        hasAlert: true,
                      ),
                    const Spacer(),
                    Text(
                      '£${tasks.fold<double>(0, (sum, t) => sum + t.guidePrice).toStringAsFixed(0)} total',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Task list — negotiating tasks appear at top with section header
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length + (negotiatingCount > 0 ? 2 : 0),
                  itemBuilder: (context, index) {
                    // If there are negotiating tasks, insert section headers
                    if (negotiatingCount > 0) {
                      if (index == 0) {
                        return _sectionHeader(
                          'Needs Decision',
                          const Color(0xFF4ECDC4),
                          negotiatingCount,
                        );
                      }
                      if (index == negotiatingCount + 1) {
                        return _sectionHeader(
                          'All Tasks',
                          const Color(0xFF6C63FF),
                          tasks.length - negotiatingCount,
                        );
                      }
                      // Offset index to account for first header
                      final taskIndex = index <= negotiatingCount
                          ? index - 1
                          : index - 2;
                      return OwnerTaskCard(task: tasks[taskIndex]);
                    }
                    return OwnerTaskCard(task: tasks[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color,
      {bool hasAlert = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAlert) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tasks will appear here once generated.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
