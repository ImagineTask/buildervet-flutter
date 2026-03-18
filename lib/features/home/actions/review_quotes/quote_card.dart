import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quote_models.dart';
import 'quote_detail_page.dart';
import 'create_quote_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteCard
//
// High-level card shown on QuoteManagementPage.
// One card per builder quote — shows builder name, task count, total, status.
// Tap → QuoteDetailPage (full breakdown + approve/decline).
// ─────────────────────────────────────────────────────────────────────────────

class QuoteCard extends StatelessWidget {
  final QuoteModel quote;
  final String currentUid;
  final String ownerId;
  final String role;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.currentUid,
    required this.ownerId,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = quote.status == 'pending';
    final isOwner = role.toLowerCase() == 'homeowner';
    final isBuilder = role.toLowerCase() == 'builder';

    return GestureDetector(
      onTap: isOwner && !isBuilder
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuoteDetailPage(
                    quote: quote,
                    role: role,
                  ),
                ),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              // ── Top row: avatar + info + amount ──────────────────────
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
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.list_alt_outlined,
                                size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${quote.breakdown.length} task${quote.breakdown.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.schedule_outlined,
                                size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${quote.createdAt.day}/${quote.createdAt.month}/${quote.createdAt.year}',
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
                            quote.totalAmount.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 20,
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
                  if (isOwner && !isBuilder) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        color: Colors.grey[300], size: 20),
                  ],
                ],
              ),

              // ── Action buttons — always shown ─────────────────────
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (role.toLowerCase() == 'builder')
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF43C59E).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 15, color: Color(0xFF43C59E)),
                        SizedBox(width: 6),
                        Text(
                          'Update Quote',
                          style: TextStyle(
                            color: Color(0xFF43C59E),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _QuoteCardActions(quote: quote),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _QuoteCardActions — inline Approve / Decline for homeowner on the card
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteCardActions extends StatefulWidget {
  final QuoteModel quote;

  const _QuoteCardActions({required this.quote});

  @override
  State<_QuoteCardActions> createState() => _QuoteCardActionsState();
}

class _QuoteCardActionsState extends State<_QuoteCardActions> {
  bool _loadingApprove = false;
  bool _loadingDecline = false;

  Future<void> _approve() async {
    setState(() => _loadingApprove = true);
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
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
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
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quote.id)
          .update({
        'status': 'declined',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
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
        // Approve
        Expanded(
          child: GestureDetector(
            onTap: _loadingApprove ? null : _approve,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _loadingApprove
                    ? const Color(0xFF43C59E).withValues(alpha: 0.5)
                    : const Color(0xFF43C59E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _loadingApprove
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              color: Colors.white, size: 15),
                          SizedBox(width: 5),
                          Text(
                            'Approve',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Decline
        Expanded(
          child: GestureDetector(
            onTap: _loadingDecline ? null : _decline,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _loadingDecline
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.5)
                    : const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _loadingDecline
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded,
                              color: Colors.white, size: 15),
                          SizedBox(width: 5),
                          Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// QuoteStatusBadge — reusable status pill
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

// ─────────────────────────────────────────────────────────────────────────────
// QuoteSummaryBar — shown at top of list when quotes exist
// ─────────────────────────────────────────────────────────────────────────────

class QuoteSummaryBar extends StatelessWidget {
  final List<QuoteModel> quotes;

  const QuoteSummaryBar({super.key, required this.quotes});

  @override
  Widget build(BuildContext context) {
    final pending = quotes.where((q) => q.status == 'pending').length;
    final accepted = quotes.where((q) => q.status == 'accepted').length;
    final lowest =
        quotes.map((q) => q.totalAmount).reduce((a, b) => a < b ? a : b);
    final highest =
        quotes.map((q) => q.totalAmount).reduce((a, b) => a > b ? a : b);

    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _Chip(
            label: '${quotes.length} Quote${quotes.length == 1 ? '' : 's'}',
            color: const Color(0xFF43C59E),
          ),
          if (pending > 0) ...[
            const SizedBox(width: 8),
            _Chip(
              label: '$pending Pending',
              color: const Color(0xFFFFB347),
              dot: true,
            ),
          ],
          if (accepted > 0) ...[
            const SizedBox(width: 8),
            _Chip(
              label: '$accepted Approved',
              color: const Color(0xFF43C59E),
            ),
          ],
          const Spacer(),
          if (quotes.length > 1)
            Text(
              '£${lowest.toStringAsFixed(0)}–£${highest.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.currency_pound,
                    size: 12, color: Colors.grey[400]),
                Text(
                  quotes.first.totalAmount.toStringAsFixed(0),
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
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const _Chip(
      {required this.label, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}