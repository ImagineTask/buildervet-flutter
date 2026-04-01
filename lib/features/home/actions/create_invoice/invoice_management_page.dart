import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../models/task_model.dart';
import 'create_invoice_page.dart';

class InvoiceManagementPage extends StatelessWidget {
  final TaskModel project;

  const InvoiceManagementPage({super.key, required this.project});

  String _formatDate(dynamic value) {
    if (value == null) return '';
    DateTime? dt;
    if (value is String) dt = DateTime.tryParse(value);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF43C59E);
      case 'overdue':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFFFB347);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Pending';
    }
  }

  Future<void> _previewFromUrl(BuildContext context, String url, String invoiceNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loader

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PdfBottomSheet(
          pdfBytes: response.bodyBytes,
          invoiceName: 'Invoice_$invoiceNumber',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          '${project.taskName} — Invoices',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateInvoicePage(project: project),
          ),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .where('projectId', isEqualTo: project.taskId)
            .where('builderId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load invoices',
                  style: TextStyle(color: Colors.grey[500])),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            final aDate =
                (a.data() as Map<String, dynamic>)['createdAt']
                    as String? ??
                    '';
            final bDate =
                (b.data() as Map<String, dynamic>)['createdAt']
                    as String? ??
                    '';
            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No invoices yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "New Invoice" to create your first invoice.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>;
              final status =
                  data['status'] as String? ?? 'pending';
              final total =
                  (data['total'] as num?)?.toDouble() ?? 0;
              final invoiceNumber =
                  data['invoiceNumber'] as String? ?? '—';
              final dueDate = _formatDate(data['dueDate']);
              final pdfUrl = data['pdfUrl'] as String?;
              final color = _statusColor(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row ──────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xFF6C63FF),
                                size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoice #$invoiceNumber',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                if (dueDate.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Due: $dueDate',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.currency_pound,
                                      size: 13,
                                      color: Color(0xFF1A1A2E)),
                                  Text(
                                    total.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  border: Border.all(
                                      color:
                                          color.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // ── Action buttons ───────────────────────
                      Row(
                        children: [
                          // Preview button
                          if (pdfUrl != null)
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.visibility_outlined,
                                label: 'Preview PDF',
                                color: const Color(0xFF6C63FF),
                                filled: true,
                                onTap: () => _previewFromUrl(
                                    context, pdfUrl, invoiceNumber),
                              ),
                            ),
                          if (pdfUrl != null)
                            const SizedBox(width: 10),

                          // Edit button
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: const Color(0xFF6C63FF),
                              filled: false,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateInvoicePage(
                                    project: project,
                                    invoiceId: docs[index].id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}