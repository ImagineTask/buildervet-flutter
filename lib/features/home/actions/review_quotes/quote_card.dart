import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quote_models.dart';
import 'quote_detail_page.dart';
import 'create_quote_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteCard
//
// One card for the entire project quote.
// Shows: builder name, total amount, status.
// Builder  → Send Quote + Update Quote
// Homeowner → Approve + Decline (updates all tasks in batch)
// Tap card  → QuoteDetailPage (breakdown per task)
// ─────────────────────────────────────────────────────────────────────────────

class QuoteCard extends StatelessWidget {
  final ProjectQuote quote;
  final List<TaskItem> tasks;
  final String role;
  final String projectId;
  final String projectName;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.tasks,
    required this.role,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final isBuilder = role.toLowerCase() == 'builder';
    final isPending = quote.status == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPending
            ? Border.all(color: const Color(0xFFFFB347), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            // ── Top row — tap to see breakdown ────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuoteDetailPage(
                    tasks: tasks,
                    quote: quote,
                    role: role,
                    projectId: projectId,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF43C59E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline,
                        size: 24, color: Color(0xFF43C59E)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.builderName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.list_alt_outlined,
                                size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${tasks.length} tasks  •  ${quote.submittedAt.day}/${quote.submittedAt.month}/${quote.submittedAt.year}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.currency_pound,
                              size: 13, color: Colors.grey[400]),
                          Text(
                            quote.total.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      QuoteStatusBadge(status: quote.status),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      color: Colors.grey[300], size: 20),
                ],
              ),
            ),

            // ── Action buttons ─────────────────────────────────────────
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            if (isBuilder)
              Row(
                children: [
                  Expanded(
                    child: _CardButton(
                      label: 'Send Quote',
                      icon: Icons.send_rounded,
                      filled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateQuotePage(
                            projectId: projectId,
                            projectName: projectName,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CardButton(
                      label: 'Update',
                      icon: Icons.edit_outlined,
                      filled: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateQuotePage(
                            projectId: projectId,
                            projectName: projectName,
                            existingTasks: tasks,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              _HomeownerActions(
                tasks: tasks,
                quote: quote,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HomeownerActions — Approve + Decline, batch updates all tasks
// ─────────────────────────────────────────────────────────────────────────────

class _HomeownerActions extends StatefulWidget {
  final List<TaskItem> tasks;
  final ProjectQuote quote;

  const _HomeownerActions({required this.tasks, required this.quote});

  @override
  State<_HomeownerActions> createState() => _HomeownerActionsState();
}

class _HomeownerActionsState extends State<_HomeownerActions> {
  bool _loadingApprove = false;
  bool _loadingDecline = false;

  Future<void> _updateAll(String status) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final task in widget.tasks) {
      if (!task.hasQuote) continue;
      final ref = FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.taskId);
      batch.update(ref, {
        'quoteStatus': status,
        'quoteResolvedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _approve() async {
    setState(() => _loadingApprove = true);
    try {
      await _updateAll('accepted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote approved'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingApprove = false);
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Quote',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        content: Text(
          'Decline the quote from ${widget.quote.builderName}?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loadingDecline = true);
    try {
      await _updateAll('declined');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDecline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CardButton(
            label: 'Approve',
            icon: Icons.check_rounded,
            filled: true,
            loading: _loadingApprove,
            onTap: _approve,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CardButton(
            label: 'Decline',
            icon: Icons.close_rounded,
            filled: true,
            color: const Color(0xFFFF6B6B),
            loading: _loadingDecline,
            onTap: _decline,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CardButton
// ─────────────────────────────────────────────────────────────────────────────

class _CardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _CardButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
    this.color = const Color(0xFF43C59E),
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled
              ? (loading ? color.withValues(alpha: 0.5) : color)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: filled ? Colors.white : color,
                      strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        color: filled ? Colors.white : color, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: filled ? Colors.white : color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QuoteStatusBadge
// ─────────────────────────────────────────────────────────────────────────────

class QuoteStatusBadge extends StatelessWidget {
  final String status;

  const QuoteStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'accepted':
        return const Color(0xFF43C59E);
      case 'declined':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFFFB347);
    }
  }

  String get _label {
    switch (status) {
      case 'accepted':
        return 'Approved';
      case 'declined':
        return 'Declined';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}