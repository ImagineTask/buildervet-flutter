import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quote_models.dart';
import 'quote_card.dart';
import 'create_quote_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteManagementPage
//
// Shows ONE quote card for the whole project.
// The card is derived from all tasks that have quote fields set.
// Empty state shows "Create a Quote" for builders, waiting message for owners.
// ─────────────────────────────────────────────────────────────────────────────

class QuoteManagementPage extends StatelessWidget {
  final String projectId;
  final String projectName;

  const QuoteManagementPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  Future<String> _fetchRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'homeowner';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return (doc.data()?['role'] as String?) ?? 'homeowner';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projectName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text(
              'Quote Management',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: _fetchRole(),
        builder: (context, roleSnapshot) {
          if (roleSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF43C59E)),
            );
          }
          final role = roleSnapshot.data ?? 'homeowner';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('parentTaskId', isEqualTo: projectId)
                .where('taskType', isEqualTo: 'task')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF43C59E)),
                );
              }

              final allTasks = (snapshot.data?.docs ?? [])
                  .map((d) => TaskItem.fromFirestore(d))
                  .toList()
                ..sort((a, b) => a.taskOrder.compareTo(b.taskOrder));

              // Derive one overall quote from all tasks
              final projectQuote = ProjectQuote.fromTasks(allTasks);

              if (projectQuote == null) {
                return _EmptyState(
                  role: role,
                  projectId: projectId,
                  projectName: projectName,
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: QuoteCard(
                  quote: projectQuote,
                  tasks: allTasks,
                  role: role,
                  projectId: projectId,
                  projectName: projectName,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String role;
  final String projectId;
  final String projectName;

  const _EmptyState({
    required this.role,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final isBuilder = role.toLowerCase() == 'builder';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.request_quote_outlined,
                size: 40,
                color: Color(0xFF43C59E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isBuilder ? 'No quote yet' : 'Awaiting quotes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBuilder
                  ? 'Submit a quote for this project to get started.'
                  : 'Builders will submit quotes for your project here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (isBuilder) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateQuotePage(
                      projectId: projectId,
                      projectName: projectName,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43C59E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Create a Quote',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}