import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quote_models.dart';
import 'quote_detail_page.dart';
import 'create_quote_page.dart';
import 'send_quote_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteCard
// ─────────────────────────────────────────────────────────────────────────────

class QuoteCard extends StatefulWidget {
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
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  String? _homeownerName;

  @override
  void initState() {
    super.initState();
    _fetchHomeownerName();
  }

  Future<void> _fetchHomeownerName() async {
    final uid = widget.quote.homeownerId;
    if (uid == null || uid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _homeownerName = doc.data()?['name'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final tasks = widget.tasks;
    final role = widget.role;
    final projectId = widget.projectId;
    final projectName = widget.projectName;
    final isBuilder = role.toLowerCase() == 'builder';
    final isPending = quote.status == 'pending';

    return GestureDetector(
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
      child: Container(
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
              // ── Top row ───────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43C59E).withValues(alpha: 0.1),
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
                        if (isBuilder && _homeownerName != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.home_outlined,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                _homeownerName!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AmountRow(
                        label: 'Quote',
                        amount: quote.total,
                        color: const Color(0xFF1A1A2E),
                      ),
                      const SizedBox(height: 4),
                      _AmountRow(
                        label: 'Agreed',
                        amount: quote.agreedTotal,
                        color: const Color(0xFF43C59E),
                      ),
                      const SizedBox(height: 6),
                      QuoteStatusBadge(status: quote.status),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      color: Colors.grey[300], size: 20),
                ],
              ),

              // ── Decline reason (builder only) ─────────────────────────
              if (isBuilder &&
                  quote.status == 'declined' &&
                  quote.declineReason != null &&
                  quote.declineReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.message_outlined,
                          size: 14, color: Color(0xFFFF6B6B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quote.declineReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── New quote alert (homeowner only) ──────────────────────
              if (!isBuilder &&
                  quote.agreedTotal > 0 &&
                  quote.total != quote.agreedTotal &&
                  quote.status != 'declined') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFFB347)
                            .withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 15, color: Color(0xFFFFB347)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A new quote has been submitted. Please review and make a decision.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFFB347),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (quote.updateReason != null &&
                          quote.updateReason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_outlined,
                                size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                quote.updateReason!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

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
                            builder: (_) => SendQuotePage(
                              projectId: projectId,
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
                  projectId: projectId, // ← pass projectId down
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HomeownerActions — Approve + Decline, batch updates all tasks
// + writes approval/decline to project-level history
// ─────────────────────────────────────────────────────────────────────────────

class _HomeownerActions extends StatefulWidget {
  final List<TaskItem> tasks;
  final ProjectQuote quote;
  final String projectId; // ← new

  const _HomeownerActions({
    required this.tasks,
    required this.quote,
    required this.projectId,
  });

  @override
  State<_HomeownerActions> createState() => _HomeownerActionsState();
}

class _HomeownerActionsState extends State<_HomeownerActions> {
  bool _loadingApprove = false;
  bool _loadingDecline = false;

  Future<void> _updateAll(String status,
      {String declineMessage = ''}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String actorName = 'Homeowner';
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      actorName = (userDoc.data()?['name'] as String?) ?? 'Homeowner';
    }

    // Project-level history entry — total is sum across ALL tasks
    final projectHistoryEntry = <String, dynamic>{
      'type': status == 'accepted' ? 'approved' : 'declined',
      'material': widget.quote.totalMaterial,
      'labour': widget.quote.totalLabour,
      'total': widget.quote.total,
      'submittedAt': DateTime.now().toIso8601String(),
      'actorName': actorName,
      if (status == 'declined' && declineMessage.isNotEmpty)
        'note': declineMessage,
    };

    // Task-level history entry (per task)
    final taskHistoryEntry = <String, dynamic>{
      'type': status == 'accepted' ? 'approved' : 'declined',
      'material': widget.quote.totalMaterial,
      'labour': widget.quote.totalLabour,
      'total': widget.quote.total,
      'submittedAt': DateTime.now().toIso8601String(),
      'actorName': actorName,
      if (status == 'declined' && declineMessage.isNotEmpty)
        'note': declineMessage,
    };

    final batch = FirebaseFirestore.instance.batch();

    // ── Child tasks ───────────────────────────────────────────────────
    for (final task in widget.tasks) {
      if (!task.hasQuote) continue;
      final ref = FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.taskId);

      final fields = <String, dynamic>{
        'quoteStatus': status,
        'quoteResolvedAt': FieldValue.serverTimestamp(),
        'quoteHistory': FieldValue.arrayUnion([taskHistoryEntry]),
      };

      if (status == 'accepted') {
        fields['agreedMaterial'] = task.quoteMaterial ?? 0;
        fields['agreedLabour'] = task.quoteLabour ?? 0;
        fields['agreedTotal'] =
            (task.quoteMaterial ?? 0) + (task.quoteLabour ?? 0);
        fields['agreedAt'] = FieldValue.serverTimestamp();
      }

      if (status == 'declined' && declineMessage.isNotEmpty) {
        fields['quoteDeclineReason'] = declineMessage;
      }

      batch.update(ref, fields);
    }

    // ── Project doc: write approval/decline to project-level history ──
    final projectRef = FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.projectId);
    batch.update(projectRef, {
      'quoteHistory': FieldValue.arrayUnion([projectHistoryEntry]),
    });

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
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Quote',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Decline the quote from ${widget.quote.builderName}?',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Leave a message for the builder (optional)',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFFF6B6B), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
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
    if (confirmed != true) {
      messageController.dispose();
      return;
    }

    final message = messageController.text.trim();
    messageController.dispose();

    setState(() => _loadingDecline = true);
    try {
      await _updateAll('declined', declineMessage: message);
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
// _AmountRow
// ─────────────────────────────────────────────────────────────────────────────

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        Icon(Icons.currency_pound, size: 11, color: color),
        Text(
          amount.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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