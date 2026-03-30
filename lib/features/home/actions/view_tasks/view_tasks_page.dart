import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import 'owner_task_card.dart';
import 'add_task_sheet.dart';

class ViewTasksPage extends StatefulWidget {
  final TaskModel project;

  const ViewTasksPage({super.key, required this.project});

  @override
  State<ViewTasksPage> createState() => _ViewTasksPageState();
}

class _ViewTasksPageState extends State<ViewTasksPage> {
  bool _reorderMode = false;

  Future<void> _onReorder(
      List<TaskModel> tasks, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final draggedTask = tasks[oldIndex];
    if (draggedTask.isActive || draggedTask.isRevising) return;

    final reordered = List<TaskModel>.from(tasks);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < reordered.length; i++) {
        final ref = FirebaseFirestore.instance
            .collection('tasks')
            .doc(reordered[i].id);
        batch.update(ref, {
          'metadata.taskOrder': i + 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddTaskSheet(BuildContext context, int nextOrderNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        project: widget.project,
        nextOrderNumber: nextOrderNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.project.taskName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('parentTaskId', isEqualTo: widget.project.taskId)
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF6B6B), size: 40),
                  const SizedBox(height: 10),
                  const Text('Failed to load tasks',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text(snapshot.error.toString(),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _EmptyState(
              onAddTask: () => _showAddTaskSheet(context, 1),
            );
          }

          final tasks = snapshot.data!.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList()
            ..sort((a, b) {
              final aOrder =
                  (a.metadata['taskOrder'] as num?)?.toInt() ?? 999;
              final bOrder =
                  (b.metadata['taskOrder'] as num?)?.toInt() ?? 999;
              return aOrder.compareTo(bOrder);
            });

          final revisingCount =
              tasks.where((t) => t.status == 'revising').length;
          final unassignedCount =
              tasks.where((t) => t.status == 'unassigned').length;

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
                    if (revisingCount > 0)
                      _summaryChip(
                        '$revisingCount Revising',
                        const Color(0xFF4ECDC4),
                        hasAlert: true,
                      ),
                    const SizedBox(width: 8),
                    if (unassignedCount > 0)
                      _summaryChip(
                        '$unassignedCount Unassigned',
                        const Color(0xFFFF6B6B),
                        hasAlert: true,
                      ),
                    const Spacer(),
                    Text(
                      '${tasks.fold<double>(0, (sum, t) => sum + t.guidePrice).toStringAsFixed(0)} total',
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

              // Mode toggle bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: _reorderMode
                    ? const Color(0xFF6C63FF).withOpacity(0.05)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    // Left hint text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _reorderMode
                          ? Row(
                              key: const ValueKey('reorder'),
                              children: [
                                Icon(Icons.drag_indicator_outlined,
                                    size: 14,
                                    color: const Color(0xFF6C63FF)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Press and drag card to reorder',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('lock'),
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 14,
                                    color: Colors.grey[400]),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap cards to view details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const Spacer(),

                    // Segmented Lock | Reorder toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lock segment
                          GestureDetector(
                            onTap: () =>
                                setState(() => _reorderMode = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: !_reorderMode
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: !_reorderMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 13,
                                    color: !_reorderMode
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Lock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: !_reorderMode
                                          ? const Color(0xFF1A1A2E)
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Reorder segment
                          GestureDetector(
                            onTap: () =>
                                setState(() => _reorderMode = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _reorderMode
                                    ? const Color(0xFF6C63FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _reorderMode
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF6C63FF)
                                              .withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.drag_indicator_outlined,
                                    size: 13,
                                    color: _reorderMode
                                        ? Colors.white
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Reorder',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _reorderMode
                                          ? Colors.white
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Task list
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF6C63FF),
                  onRefresh: () async => await Future.delayed(
                      const Duration(milliseconds: 800)),
                  child: ReorderableListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: tasks.length,
                    onReorder: _reorderMode
                        ? (oldIndex, newIndex) =>
                            _onReorder(tasks, oldIndex, newIndex)
                        : (_, __) {},
                    proxyDecorator: (child, index, animation) =>
                        AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        shadowColor: Colors.black26,
                        child: child,
                      ),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isLocked =
                          task.isActive || task.isRevising;

                      return _TaskCardRow(
                        key: ValueKey(task.id),
                        task: task,
                        index: index,
                        isLocked: isLocked,
                        reorderMode: _reorderMode,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // FAB — hidden in reorder mode
      floatingActionButton: _reorderMode
          ? null
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('parentTaskId',
                      isEqualTo: widget.project.taskId)
                  .where('taskType', isEqualTo: 'task')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return FloatingActionButton.extended(
                  onPressed: () =>
                      _showAddTaskSheet(context, count + 1),
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                );
              },
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
// Task Card Row
// ─────────────────────────────────────────────
class _TaskCardRow extends StatelessWidget {
  final TaskModel task;
  final int index;
  final bool isLocked;
  final bool reorderMode;

  const _TaskCardRow({
    super.key,
    required this.task,
    required this.index,
    required this.isLocked,
    required this.reorderMode,
  });

  @override
  Widget build(BuildContext context) {
    final canDrag = reorderMode && !isLocked;

    final cardWidget = Opacity(
      opacity: reorderMode ? (isLocked ? 0.5 : 0.85) : 1.0,
      child: OwnerTaskCard(
        task: task,
        orderNumber: index + 1,
        reorderMode: reorderMode,
      ),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reorderMode)
          Padding(
            padding: const EdgeInsets.only(
                top: 18, right: 6, bottom: 12),
            child: Tooltip(
              message: isLocked
                  ? task.isActive
                      ? 'Cannot reorder active task'
                      : 'Cannot reorder task under revision'
                  : '',
              child: Icon(
                canDrag
                    ? Icons.drag_indicator_outlined
                    : Icons.lock_outline,
                size: canDrag ? 22 : 18,
                color: canDrag
                    ? Colors.grey[400]
                    : Colors.grey[300],
              ),
            ),
          ),
        Expanded(child: cardWidget),
      ],
    );

    if (canDrag) {
      return ReorderableDragStartListener(
        index: index,
        child: row,
      );
    }

    return row;
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddTask;
  const _EmptyState({required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.task_outlined,
              size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tasks will appear here once generated.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}