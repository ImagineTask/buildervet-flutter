import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../../Cards/Task/task_project_type_card.dart';
import '../actions/action_registry.dart';
import '../actions/marketing/marketing_action.dart';
import '../actions/customised/customised_action.dart';
import '../actions/customised/custom_tile_service.dart';
import '../actions/customised/custom_tile_model.dart';
import '../actions/customised/custom_tile_widget.dart';
import '../state/project_selection_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (mounted) setState(() {});
  }

  Future<void> _onCardTapped(TaskModel project) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSelectionSheet(
        project: project,
        onDeleted: () {
          if (_selection.selectedProjectId == project.taskId) {
            _selection.clear();
          }
        },
      ),
    );
    if (confirmed == true) {
      _selection.select(project.taskId);
    }
  }

  Future<void> _onSelectedCardTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deselect Project?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: const Text('This will return you to the project list.',
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
    final customTileService = CustomTileService();
    final systemActions = [
      ...ActionRegistry.resolveAll(project),
      MarketingAction(project: project),
    ];

    return StreamBuilder<List<CustomTileModel>>(
      stream: customTileService.streamTiles(project.id),
      builder: (context, snapshot) {
        final customTiles = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

            GestureDetector(
              onTap: onCardTapped,
              child: TaskProjectTypeCard(
                  project: project, service: service, showViewTasks: false),
            ),
            const SizedBox(height: 20),

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
              children: [
                ...systemActions,
                ...customTiles.map((tile) => CustomTileWidget(
                      tile: tile,
                      projectId: project.id,
                      service: customTileService,
                    )),
                CustomisedAction(project: project),
              ],
            ),
            const SizedBox(height: 20),

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
      },
    );
  }
}

// ─────────────────────────────────────────────
// Confirm Selection Bottom Sheet
// ─────────────────────────────────────────────
class _ConfirmSelectionSheet extends StatefulWidget {
  final TaskModel project;
  final VoidCallback onDeleted;

  const _ConfirmSelectionSheet({
    required this.project,
    required this.onDeleted,
  });

  @override
  State<_ConfirmSelectionSheet> createState() =>
      _ConfirmSelectionSheetState();
}

class _ConfirmSelectionSheetState extends State<_ConfirmSelectionSheet> {
  bool _deleting = false;

  Color get _statusColor {
    switch (widget.project.status) {
      case 'active':
        return const Color(0xFF6C63FF);
      case 'done':
        return const Color(0xFF43C59E);
      default:
        return const Color(0xFFFFB347);
    }
  }

  // Deletes all known subcollections of a task doc, then the doc itself
  Future<void> _deleteDocWithSubcollections(DocumentReference ref) async {
    const subcollections = ['events']; // add more here if needed

    for (final sub in subcollections) {
      final subSnap = await ref.collection(sub).get();
      if (subSnap.docs.isEmpty) continue;

      const batchSize = 499;
      final docs = subSnap.docs;
      for (var i = 0; i < docs.length; i += batchSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = docs.skip(i).take(batchSize);
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    await ref.delete();
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Project?',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.project.taskName}"?',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFFF6B6B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently delete the project and all its tasks. This cannot be undone.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF6B6B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);

    try {
      final db = FirebaseFirestore.instance;

      // Fetch all child tasks linked to this project
      final childTasks = await db
          .collection('tasks')
          .where('parentTaskId', isEqualTo: widget.project.taskId)
          .get();

      // Delete each child task with its subcollections
      for (final taskDoc in childTasks.docs) {
        await _deleteDocWithSubcollections(taskDoc.reference);
      }

      // Delete the project task itself with its subcollections
      await _deleteDocWithSubcollections(
        db.collection('tasks').doc(widget.project.taskId),
      );

      widget.onDeleted();

      if (mounted) {
        Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '"${widget.project.taskName}" and its tasks have been deleted.'),
            backgroundColor: const Color(0xFF43C59E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete project. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          // Drag handle
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

          // Project name + status dot
          Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.project.taskName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.project.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          // Select button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _deleting ? null : () => Navigator.of(context).pop(true),
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

          // Delete button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleting ? null : _deleteProject,
              icon: _deleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF6B6B)),
                    )
                  : const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFFF6B6B)),
              label: Text(
                _deleting ? 'Deleting...' : 'Delete Project',
                style: const TextStyle(color: Color(0xFFFF6B6B)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                    color: const Color(0xFFFF6B6B).withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  _deleting ? null : () => Navigator.of(context).pop(false),
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