import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quote_models.dart';
import 'quote_card.dart';
import 'create_quote_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteManagementPage
//
// Contractor:
//   Empty  → "Create a Quote" button → CreateQuotePage
//   Quoted → QuoteCard per submitted quote + "Update Quote" button
//
// Homeowner:
//   Empty  → "Awaiting quotes" message
//   Quoted → QuoteCard per builder quote → tap → QuoteDetailPage
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
          final isContractor = role == 'contractor';
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('quotes')
                .where('projectId', isEqualTo: projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF43C59E)),
                );
              }

              final allQuotes = (snapshot.data?.docs ?? [])
                  .map((d) => QuoteModel.fromFirestore(d))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              // Contractor only sees their own quotes
              final visibleQuotes = isContractor
                  ? allQuotes
                      .where((q) => q.builderId == uid)
                      .toList()
                  : allQuotes;

              if (visibleQuotes.isEmpty) {
                return _EmptyState(
                  isContractor: isContractor,
                  projectId: projectId,
                  projectName: projectName,
                );
              }

              return Column(
                children: [
                  QuoteSummaryBar(quotes: visibleQuotes),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleQuotes.length +
                          (isContractor ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Contractor gets "Update Quote" at the bottom
                        if (isContractor &&
                            index == visibleQuotes.length) {
                          return Padding(
                            padding: const EdgeInsets.only(
                                top: 4, bottom: 24),
                            child: _UpdateQuoteButton(
                              projectId: projectId,
                              projectName: projectName,
                            ),
                          );
                        }
                        return QuoteCard(
                            quote: visibleQuotes[index]);
                      },
                    ),
                  ),
                ],
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
  final bool isContractor;
  final String projectId;
  final String projectName;

  const _EmptyState({
    required this.isContractor,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
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
              isContractor ? 'No quote yet' : 'Awaiting quotes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isContractor
                  ? 'Submit a quote for this project to get started.'
                  : 'Builders will submit quotes for your project here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: isContractor
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateQuotePage(
                            projectId: projectId,
                            projectName: projectName,
                          ),
                        ),
                      )
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: isContractor
                      ? const Color(0xFF43C59E)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isContractor
                          ? Icons.add_circle_outline
                          : Icons.hourglass_empty_rounded,
                      color:
                          isContractor ? Colors.white : Colors.grey[500],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isContractor
                          ? 'Create a Quote'
                          : 'Request a Quote',
                      style: TextStyle(
                        color: isContractor
                            ? Colors.white
                            : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Update Quote Button — contractor can resubmit after quoting
// ─────────────────────────────────────────────────────────────────────────────

class _UpdateQuoteButton extends StatelessWidget {
  final String projectId;
  final String projectName;

  const _UpdateQuoteButton({
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF43C59E).withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, size: 16, color: Color(0xFF43C59E)),
            SizedBox(width: 8),
            Text(
              'Update Quote',
              style: TextStyle(
                color: Color(0xFF43C59E),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
