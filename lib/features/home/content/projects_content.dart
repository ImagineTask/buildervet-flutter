import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../../Cards/Task/task_project_type_card.dart';

class ProjectsContent extends StatelessWidget {
  const ProjectsContent({super.key});

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

        final draft = projects.where((p) => p.status == 'draft').toList();
        final active = projects.where((p) => p.status == 'active').toList();
        final done = projects.where((p) => p.status == 'done').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary chips
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
              ...active.map((p) =>
                  TaskProjectTypeCard(project: p, service: service)),
            ],
            if (draft.isNotEmpty) ...[
              if (active.isNotEmpty) const SizedBox(height: 16),
              _SectionHeader(title: 'Draft', count: draft.length),
              const SizedBox(height: 10),
              ...draft.map((p) =>
                  TaskProjectTypeCard(project: p, service: service)),
            ],
            if (done.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader(title: 'Completed', count: done.length),
              const SizedBox(height: 10),
              ...done.map((p) =>
                  TaskProjectTypeCard(project: p, service: service)),
            ],
          ],
        );
      },
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