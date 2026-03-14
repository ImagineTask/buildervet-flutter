import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../../Cards/Task/task_project_type_card.dart';
import '../actions/action_registry.dart';
import '../state/project_selection_state.dart';

class ProjectsContent extends StatefulWidget {
  const ProjectsContent({super.key});

  @override
  State<ProjectsContent> createState() => _ProjectsContentState();
}

class _ProjectsContentState extends State<ProjectsContent> {
  late ProjectSelectionController _selection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-subscribe whenever dependencies change
    _selection = ProjectSelectionState.of(context);
    _selection.removeListener(_onSelectionChanged);
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    // Triggers an immediate rebuild when selection changes
    if (mounted) setState(() {});
  }

  // ── Tap card in list → confirm selection ─────────────────────────────────
  Future<void> _onCardTapped(TaskModel project) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSelectionSheet(project: project),
    );
    if (confirmed == true) {
      _selection.select(project.taskId);
    }
  }

  // ── Tap selected card → confirm deselection ───────────────────────────────
  Future<void> _onSelectedCardTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deselect Project?',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: const Text(
            'This will return you to the project list.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
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
      _selection.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = TasksService();

    return StreamBuilder<List<TaskModel>>(
      stream: service.streamProjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }

        final projects = snapshot.data ?? [];
        if (projects.isEmpty) return const _EmptyState();

        // ── Selected view ─────────────────────────────────────────────────
        if (_selection.selectedProjectId != null) {
          final matchIndex = projects
              .indexWhere((p) => p.taskId == _selection.selectedProjectId);

          if (matchIndex == -1) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _selection.clear());
          } else {
            return _SelectedProjectView(
              project: projects[matchIndex],
              service: service,
              onCardTapped: _onSelectedCardTapped,
              onSwitch: _selection.clear,
            );
          }
        }

        // ── Project list ──────────────────────────────────────────────────
        final draft = projects.where((p) => p.status == 'draft').toList();
        final active = projects.where((p) => p.status == 'active').toList();
        final done = projects.where((p) => p.status == 'done').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SummaryChip(
                    label: 'Draft',
                    count: draft.length,
                    color: const Color(0xFFFFB347)),
                const SizedBox(width: 10),
                _SummaryChip(
                    label: 'Active',
                    count: active.length,
                    color: const Color(0xFF6C63FF)),
                const SizedBox(width: 10),
                _SummaryChip(
                    label: 'Done',
                    count: done.length,
                    color: const Color(0xFF43C59E)),
              ],
            ),
            const SizedBox(height: 20),

            if (active.isNotEmpty) ...[
              _SectionHeader(title: 'Active', count: active.length),
              const SizedBox(height: 10),
              ...active.map((p) => GestureDetector(
                    onTap: () => _onCardTapped(p),
                    child: TaskProjectTypeCard(project: p, service: service),
                  )),
            ],
            if (draft.isNotEmpty) ...[
              if (active.isNotEmpty) const SizedBox(height: 16),
              _SectionHeader(title: 'Draft', count: draft.length),
              const SizedBox(height: 10),
              ...draft.map((p) => GestureDetector(
                    onTap: () => _onCardTapped(p),
                    child: TaskProjectTypeCard(project: p, service: service),
                  )),
            ],
            if (done.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader(title: 'Completed', count: done.length),
              const SizedBox(height: 10),
              ...done.map((p) => GestureDetector(
                    onTap: () => _onCardTapped(p),
                    child: TaskProjectTypeCard(project: p, service: service),
                  )),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Selected Project View
// ─────────────────────────────────────────────
class _SelectedProjectView extends StatelessWidget {
  final TaskModel project;
  final TasksService service;
  final VoidCallback onCardTapped;
  final VoidCallback onSwitch;

  const _SelectedProjectView({
    required this.project,
    required this.service,
    required this.onCardTapped,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final actions = ActionRegistry.resolveAll(project);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Selected Project" pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                'Selected Project',
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

        // Tap card to trigger deselect dialog
        GestureDetector(
          onTap: onCardTapped,
          child: TaskProjectTypeCard(
              project: project, service: service, showViewTasks: false),
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

        // Switch project button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.swap_horiz_rounded,
                size: 16, color: Color(0xFF6C63FF)),
            label: const Text('Switch Project',
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

// ─────────────────────────────────────────────
// Confirm Selection Bottom Sheet
// ─────────────────────────────────────────────
class _ConfirmSelectionSheet extends StatelessWidget {
  final TaskModel project;
  const _ConfirmSelectionSheet({required this.project});

  Color get _statusColor {
    switch (project.status) {
      case 'active':
        return const Color(0xFF6C63FF);
      case 'done':
        return const Color(0xFF43C59E);
      default:
        return const Color(0xFFFFB347);
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
                child: Text(project.taskName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(project.description,
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
              child: const Text('Select Project'),
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
                style:
                    TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            Text('Loading projects...',
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
          const Text('Failed to load projects',
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
          Icon(Icons.folder_open_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No projects yet',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text('Projects you create will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
      );
}