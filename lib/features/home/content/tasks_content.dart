import 'package:flutter/material.dart';

class TasksContent extends StatefulWidget {
  const TasksContent({super.key});

  @override
  State<TasksContent> createState() => _TasksContentState();
}

class _TasksContentState extends State<TasksContent> {
  final List<_Task> _tasks = List.from(_defaultTasks);

  void _toggleTask(int index) {
    setState(() {
      _tasks[index] = _Task(
        title: _tasks[index].title,
        subtitle: _tasks[index].subtitle,
        priority: _tasks[index].priority,
        isDone: !_tasks[index].isDone,
        dueDate: _tasks[index].dueDate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => !t.isDone).toList();
    final completed = _tasks.where((t) => t.isDone).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task summary chips
        Row(
          children: [
            _TaskChip(
              label: '${pending.length} Pending',
              color: const Color(0xFFFF6B6B),
            ),
            const SizedBox(width: 8),
            _TaskChip(
              label: '${completed.length} Done',
              color: const Color(0xFF43C59E),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Pending',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        ...pending.asMap().entries.map((e) => _TaskTile(
              task: e.value,
              onToggle: () => _toggleTask(_tasks.indexOf(e.value)),
            )),

        if (completed.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Completed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          ...completed.map((t) => _TaskTile(
                task: t,
                onToggle: () => _toggleTask(_tasks.indexOf(t)),
              )),
        ],
      ],
    );
  }
}

class _TaskChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TaskChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

enum _Priority { high, medium, low }

class _Task {
  final String title;
  final String subtitle;
  final _Priority priority;
  final bool isDone;
  final String dueDate;

  const _Task({
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.isDone,
    required this.dueDate,
  });
}

final _defaultTasks = [
  _Task(
    title: 'Review design mockups',
    subtitle: 'Mobile App Redesign',
    priority: _Priority.high,
    isDone: false,
    dueDate: 'Today',
  ),
  _Task(
    title: 'Write unit tests for API',
    subtitle: 'Backend Migration',
    priority: _Priority.high,
    isDone: false,
    dueDate: 'Tomorrow',
  ),
  _Task(
    title: 'Update project documentation',
    subtitle: 'General',
    priority: _Priority.medium,
    isDone: false,
    dueDate: 'Mar 14',
  ),
  _Task(
    title: 'Prepare Q2 budget report',
    subtitle: 'Finance',
    priority: _Priority.medium,
    isDone: false,
    dueDate: 'Mar 16',
  ),
  _Task(
    title: 'Send weekly team update',
    subtitle: 'Management',
    priority: _Priority.low,
    isDone: true,
    dueDate: 'Mar 9',
  ),
  _Task(
    title: 'Set up CI/CD pipeline',
    subtitle: 'DevOps',
    priority: _Priority.low,
    isDone: true,
    dueDate: 'Mar 8',
  ),
];

class _TaskTile extends StatelessWidget {
  final _Task task;
  final VoidCallback onToggle;
  const _TaskTile({required this.task, required this.onToggle});

  Color get _priorityColor {
    switch (task.priority) {
      case _Priority.high:
        return const Color(0xFFFF6B6B);
      case _Priority.medium:
        return const Color(0xFFFFB347);
      case _Priority.low:
        return const Color(0xFF43C59E);
    }
  }

  String get _priorityLabel {
    switch (task.priority) {
      case _Priority.high:
        return 'High';
      case _Priority.medium:
        return 'Med';
      case _Priority.low:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isDone
                    ? const Color(0xFF43C59E)
                    : Colors.transparent,
                border: Border.all(
                  color: task.isDone
                      ? const Color(0xFF43C59E)
                      : Colors.grey.shade300,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: task.isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: task.isDone
                        ? Colors.grey[400]
                        : const Color(0xFF1A1A2E),
                    decoration:
                        task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _priorityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _priorityColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task.dueDate,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
