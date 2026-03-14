import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Home/models/task_model.dart';
import '../../Home/actions/action_registry.dart';
import '../../Cards/Task/task_assigned_type_card.dart';

class TasksContent extends StatefulWidget {
  const TasksContent({super.key});

  @override
  State<TasksContent> createState() => _TasksContentState();
}

class _TasksContentState extends State<TasksContent> {
  String? _selectedTaskId;

  Stream<List<TaskModel>> _streamAssignedTasks() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedBuilderIds', arrayContains: uid)
        .where('taskType', isEqualTo: 'task')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TaskModel.fromFirestore(d)).toList());
  }

  Future<void> _onCardTapped(TaskModel task) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmTaskSelectionSheet(task: task),
    );
    if (confirmed == true) {
      setState(() => _selectedTaskId = task.id);
    }
  }

  Future<void> _onSelectedCardTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deselect Task?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: const Text('This will return you to the task list.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Deselect'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _selectedTaskId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<List<TaskModel>>(
      stream: _streamAssignedTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) return const _EmptyState();

        // ── Selected task view ───────────────────────────────────────────
        if (_selectedTaskId != null) {
          final matchIndex =
              tasks.indexWhere((t) => t.id == _selectedTaskId);

          if (matchIndex == -1) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => setState(() => _selectedTaskId = null));
          } else {
            final selectedTask = tasks[matchIndex];
            // Build actions from actionSpace — falls back to accept/deny/negotiate
            // if task is pending_acceptance and has no specific actionSpace
            final actions = selectedTask.actionSpace.isNotEmpty
                ? ActionRegistry.resolveAll(selectedTask)
                : _defaultActionsFor(selectedTask);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Selected Task" pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 12, color: Color(0xFF6C63FF)),
                      SizedBox(width: 4),
                      Text(
                        'Selected Task',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Selected task card
                GestureDetector(
                  onTap: _onSelectedCardTapped,
                  child: TaskAssignedTypeCard(task: selectedTask),
                ),
                const SizedBox(height: 20),

                // Action grid
                if (actions.isNotEmpty) ...[
                  const Text(
                    'Actions',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                    children: actions,
                  ),
                  const SizedBox(height: 20),
                ],

                // Switch task button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedTaskId = null),
                    icon: const Icon(Icons.swap_horiz_rounded,
                        size: 16, color: Color(0xFF6C63FF)),
                    label: const Text('Switch Task',
                        style: TextStyle(color: Color(0xFF6C63FF))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            );
          }
        }

        // ── Task list ────────────────────────────────────────────────────
        final pending = tasks
            .where((t) => t.status == 'pending_acceptance')
            .toList();
        final negotiating =
            tasks.where((t) => t.status == 'negotiating').toList();
        final active =
            tasks.where((t) => t.status == 'active').toList();
        final done = tasks.where((t) => t.status == 'done').toList();
        final denied =
            tasks.where((t) => t.status == 'denied').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary chips
            Row(
              children: [
                if (pending.isNotEmpty)
                  _SummaryChip(
                      label: 'Awaiting',
                      count: pending.length,
                      color: const Color(0xFFFFB347)),
                if (pending.isNotEmpty && active.isNotEmpty)
                  const SizedBox(width: 10),
                if (active.isNotEmpty)
                  _SummaryChip(
                      label: 'Active',
                      count: active.length,
                      color: const Color(0xFF6C63FF)),
                if (active.isNotEmpty && done.isNotEmpty)
                  const SizedBox(width: 10),
                if (done.isNotEmpty)
                  _SummaryChip(
                      label: 'Done',
                      count: done.length,
                      color: const Color(0xFF43C59E)),
              ],
            ),
            const SizedBox(height: 20),

            if (pending.isNotEmpty) ...[
              _SectionHeader(
                  title: 'Awaiting Response', count: pending.length),
              const SizedBox(height: 10),
              ...pending.map((t) => GestureDetector(
                    onTap: () => _onCardTapped(t),
                    child: TaskAssignedTypeCard(task: t),
                  )),
            ],
            if (negotiating.isNotEmpty) ...[
              if (pending.isNotEmpty) const SizedBox(height: 16),
              _SectionHeader(
                  title: 'Negotiating', count: negotiating.length),
              const SizedBox(height: 10),
              ...negotiating.map((t) => GestureDetector(
                    onTap: () => _onCardTapped(t),
                    child: TaskAssignedTypeCard(task: t),
                  )),
            ],
            if (active.isNotEmpty) ...[
              if (pending.isNotEmpty || negotiating.isNotEmpty)
                const SizedBox(height: 16),
              _SectionHeader(title: 'Active', count: active.length),
              const SizedBox(height: 10),
              ...active.map((t) => GestureDetector(
                    onTap: () => _onCardTapped(t),
                    child: TaskAssignedTypeCard(task: t),
                  )),
            ],
            if (done.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader(title: 'Completed', count: done.length),
              const SizedBox(height: 10),
              ...done.map((t) => GestureDetector(
                    onTap: () => _onCardTapped(t),
                    child: TaskAssignedTypeCard(task: t),
                  )),
            ],
            if (denied.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader(title: 'Denied', count: denied.length),
              const SizedBox(height: 10),
              ...denied.map((t) => GestureDetector(
                    onTap: () => _onCardTapped(t),
                    child: TaskAssignedTypeCard(task: t),
                  )),
            ],
          ],
        );
      },
    );
  }

  /// Default actions when task has no actionSpace defined
  List<Widget> _defaultActionsFor(TaskModel task) {
    if (task.status == 'pending_acceptance') {
      return ActionRegistry.resolveAll(task.copyWith(
        actionSpace: ['accept_task', 'deny_task', 'negotiate_task'],
      ));
    }
    return [];
  }
}

// ─────────────────────────────────────────────
// Confirm Task Selection Sheet
// ─────────────────────────────────────────────
class _ConfirmTaskSelectionSheet extends StatelessWidget {
  final TaskModel task;
  const _ConfirmTaskSelectionSheet({required this.task});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.taskName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (task.description.isNotEmpty)
            Text(task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Select Task'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Summary Chip
// ─────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF))),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Loading / Error / Empty states
// ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(children: [
            CircularProgressIndicator(color: Color(0xFF6C63FF)),
            SizedBox(height: 12),
            Text('Loading tasks...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFFF6B6B), size: 40),
          const SizedBox(height: 10),
          const Text('Failed to load tasks',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(message,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.task_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No tasks assigned to you',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text('Tasks assigned to you will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
      );
}