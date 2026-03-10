import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Home/models/task_model.dart';
import '../../Home/services/tasks_service.dart';

// ─────────────────────────────────────────────
// Project Card (taskType == "project")
// ─────────────────────────────────────────────
class TaskProjectTypeCard extends StatefulWidget {
  final TaskModel project;
  final TasksService service;

  const TaskProjectTypeCard({
    super.key,
    required this.project,
    required this.service,
  });

  @override
  State<TaskProjectTypeCard> createState() => _TaskProjectTypeCardState();
}

class _TaskProjectTypeCardState extends State<TaskProjectTypeCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.project.status) {
      case 'active':
        return const Color(0xFF6C63FF);
      case 'done':
        return const Color(0xFF43C59E);
      default: // draft
        return const Color(0xFFFFB347);
    }
  }

  String get _formattedEndDate =>
      DateFormat('MMM d').format(widget.project.endTime);

  String get _priceBand {
    final f = NumberFormat.compact();
    return '£${f.format(widget.project.guidePriceMin)} – £${f.format(widget.project.guidePriceMax)}';
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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
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
                        widget.project.taskName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ProjectStatusBadge(
                        status: widget.project.status, color: _statusColor),
                  ],
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  widget.project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 12),

                // Info row: duration + price band + due date
                Row(
                  children: [
                    ProjectInfoChip(
                        icon: Icons.schedule_outlined,
                        label: '${widget.project.durationDays}d'),
                    const SizedBox(width: 8),
                    ProjectInfoChip(
                        icon: Icons.currency_pound, label: _priceBand),
                    const Spacer(),
                    Icon(Icons.flag_outlined,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      _formattedEndDate,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // View tasks toggle
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? 'Hide tasks' : 'View tasks',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6C63FF)),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: Color(0xFF6C63FF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expandable task list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: ProjectTasksSubList(
                projectTaskId: widget.project.taskId,
                service: widget.service),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────
class ProjectStatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const ProjectStatusBadge(
      {super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Info Chip
// ─────────────────────────────────────────────
class ProjectInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const ProjectInfoChip(
      {super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Tasks Sub-list (child tasks by parentTaskId)
// ─────────────────────────────────────────────
class ProjectTasksSubList extends StatelessWidget {
  final String projectTaskId;
  final TasksService service;

  const ProjectTasksSubList(
      {super.key, required this.projectTaskId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: service.streamTasksForProject(projectTaskId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text('No tasks yet',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: tasks.map((t) => ProjectTaskRow(task: t)).toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Task Row (child task inside a project card)
// ─────────────────────────────────────────────
class ProjectTaskRow extends StatelessWidget {
  final TaskModel task;

  const ProjectTaskRow({super.key, required this.task});

  String get _formattedDates {
    final start = DateFormat('MMM d').format(task.startTime);
    final end = DateFormat('MMM d').format(task.endTime);
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';
    final orderNum = task.metadata['taskOrder'];
    final dependsOn = task.metadata['dependsOn'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number circle
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF43C59E)
                  : const Color(0xFF6C63FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : Text(
                      '$orderNum',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF)),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isDone ? Colors.grey[400] : const Color(0xFF1A1A2E),
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                if (task.contractorType != null)
                  Text(task.contractorType!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400])),
                if (dependsOn != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward,
                          size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'After: $dependsOn',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400]),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '£${task.guidePrice.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 2),
              Text(
                _formattedDates,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
