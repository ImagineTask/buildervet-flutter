import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quote_models.dart';
import 'quote_card.dart';
import 'create_quote_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteDetailPage
//
// Shown when user taps a QuoteCard.
// Displays the full task breakdown with amounts, plus approve/decline.
// ─────────────────────────────────────────────────────────────────────────────

class QuoteDetailPage extends StatelessWidget {
  final QuoteModel quote;
  final String role;

  const QuoteDetailPage({super.key, required this.quote, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          quote.builderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card — builder + total + status ────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 22, color: Color(0xFF43C59E)),
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
                      Text(
                        '${quote.createdAt.day}/${quote.createdAt.month}/${quote.createdAt.year}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
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
                            size: 14, color: Colors.grey[400]),
                        Text(
                          quote.totalAmount.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    QuoteStatusBadge(status: quote.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Breakdown card ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    'Task Breakdown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Breakdown rows
                ...quote.breakdown.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task icon
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF43C59E)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.build_outlined,
                                  size: 15, color: Color(0xFF43C59E)),
                            ),
                            const SizedBox(width: 10),

                            // Task name + notes
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.taskName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Amount
                            const SizedBox(width: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.currency_pound,
                                    size: 11, color: Colors.grey[400]),
                                Text(
                                  item.amount.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                // Total row
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.currency_pound,
                              size: 13, color: Colors.grey[400]),
                          Text(
                            quote.totalAmount.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF43C59E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Role-aware actions ───────────────────────────────────────
          const SizedBox(height: 20),
          if (role.toLowerCase() == 'homeowner') ...[
            _ApproveButton(quote: quote),
            const SizedBox(height: 10),
            _DeclineButton(quote: quote),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Contractor Actions — shown instead of approve/decline for contractors
// ─────────────────────────────────────────────────────────────────────────────

class _ContractorActions extends StatelessWidget {
  final QuoteModel quote;

  const _ContractorActions({required this.quote});

  @override
  Widget build(BuildContext context) {
    final isPending = quote.status == 'pending';
    final isDeclined = quote.status == 'declined';

    return Column(
      children: [
        // Status info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPending
                ? const Color(0xFFFFB347).withValues(alpha: 0.1)
                : isDeclined
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.1)
                    : const Color(0xFF43C59E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPending
                  ? const Color(0xFFFFB347).withValues(alpha: 0.3)
                  : isDeclined
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
                      : const Color(0xFF43C59E).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPending
                    ? Icons.hourglass_empty_rounded
                    : isDeclined
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                size: 16,
                color: isPending
                    ? const Color(0xFFFFB347)
                    : isDeclined
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF43C59E),
              ),
              const SizedBox(width: 8),
              Text(
                isPending
                    ? 'Awaiting homeowner review'
                    : isDeclined
                        ? 'This quote was declined'
                        : 'This quote was approved',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPending
                      ? const Color(0xFFFFB347)
                      : isDeclined
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF43C59E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Update quote button — always available to contractor
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateQuotePage(
                projectId: quote.projectId,
                projectName: '',
              ),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF43C59E).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined,
                    size: 16, color: Color(0xFF43C59E)),
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
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approve Button
// ─────────────────────────────────────────────────────────────────────────────

class _ApproveButton extends StatefulWidget {
  final QuoteModel quote;
  const _ApproveButton({required this.quote});

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quote.id)
          .update({
        'status': 'accepted',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote approved'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
        Navigator.pop(context);
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ActionButton(
        label: 'Approve Quote',
        icon: Icons.check_rounded,
        color: const Color(0xFF43C59E),
        loading: _loading,
        onTap: _approve,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Decline Button
// ─────────────────────────────────────────────────────────────────────────────

class _DeclineButton extends StatefulWidget {
  final QuoteModel quote;
  const _DeclineButton({required this.quote});

  @override
  State<_DeclineButton> createState() => _DeclineButtonState();
}

class _DeclineButtonState extends State<_DeclineButton> {
  bool _loading = false;

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

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quote.id)
          .update({
        'status': 'declined',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ActionButton(
        label: 'Decline Quote',
        icon: Icons.close_rounded,
        color: const Color(0xFFFF6B6B),
        loading: _loading,
        onTap: _decline,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: loading ? color.withValues(alpha: 0.5) : color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}