import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import 'task_detail_page.dart';

class OwnerTaskCard extends StatefulWidget {
  final TaskModel task;

  const OwnerTaskCard({super.key, required this.task});

  @override
  State<OwnerTaskCard> createState() => _OwnerTaskCardState();
}

class _OwnerTaskCardState extends State<OwnerTaskCard> {
  // ── Helpers ─────────────────────────────────────────────────────────────

  bool get _hasNegotiation =>
      widget.task.metadata['negotiation'] != null &&
      widget.task.status == 'negotiating';

  Map<String, dynamic> get _negotiation =>
      Map<String, dynamic>.from(widget.task.metadata['negotiation'] ?? {});

  List<String> get _scheduledDates {
    final dates = widget.task.metadata['scheduledDates'];
    if (dates == null) return [];
    return List<String>.from(dates as List);
  }

  Color get _statusColor {
    switch (widget.task.status) {
      case 'pending_acceptance':
        return const Color(0xFFFFB347);
      case 'active':
        return const Color(0xFF6C63FF);
      case 'negotiating':
        return const Color(0xFF4ECDC4);
      case 'done':
        return const Color(0xFF43C59E);
      case 'denied':
        return const Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (widget.task.status) {
      case 'pending_acceptance':
        return 'Awaiting';
      case 'active':
        return 'Active';
      case 'negotiating':
        return 'Negotiating';
      case 'done':
        return 'Done';
      case 'denied':
        return 'Denied';
      default:
        return widget.task.status;
    }
  }

  String _formatScheduledDate(String iso) {
    try {
      final date = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM').format(date);
    } catch (_) {
      return iso;
    }
  }

  // ── Accept negotiation ───────────────────────────────────────────────────
  Future<void> _acceptNegotiation(BuildContext context) async {
    final requestedFee =
        (_negotiation['requestedFee'] as num?)?.toDouble() ?? 0;

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'status': 'active',
        'guidePrice': requestedFee,
        'metadata.negotiation.resolvedAt':
            DateTime.now().toIso8601String(),
        'metadata.negotiation.resolution': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Negotiation accepted — task is now active'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Decline negotiation ──────────────────────────────────────────────────
  Future<void> _declineNegotiation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Negotiation',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        content: const Text(
            'The task will be marked as denied.',
            style: TextStyle(color: Colors.grey)),
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

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.task.id)
            .update({
          'status': 'denied',
          'metadata.negotiation.resolvedAt':
              DateTime.now().toIso8601String(),
          'metadata.negotiation.resolution': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to decline. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Counter offer ────────────────────────────────────────────────────────
  Future<void> _counterOffer(BuildContext context) async {
    final controller = TextEditingController(
        text: widget.task.guidePrice.toStringAsFixed(0));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Counter Offer',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              Text(
                'Builder requested: £${(_negotiation['requestedFee'] as num?)?.toStringAsFixed(0) ?? '0'}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Your counter offer',
                  prefixIcon: const Icon(Icons.currency_pound,
                      color: Color(0xFF6C63FF)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF6C63FF), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final fee =
                        double.tryParse(controller.text) ?? 0;
                    Navigator.pop(context);
                    await FirebaseFirestore.instance
                        .collection('tasks')
                        .doc(widget.task.id)
                        .update({
                      'guidePrice': fee,
                      'metadata.negotiation.counterOffer': fee,
                      'metadata.negotiation.counterOfferedAt':
                          DateTime.now().toIso8601String(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Counter offer sent'),
                          backgroundColor: Color(0xFF6C63FF),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Counter Offer',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final dates = _scheduledDates;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailPage(task: task),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: _hasNegotiation
              ? Border.all(color: const Color(0xFF4ECDC4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task name + status
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.taskName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Contractor type
                  if (task.contractorType != null)
                    Row(
                      children: [
                        Icon(Icons.work_outline,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(task.contractorType!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  const SizedBox(height: 6),

                  // Assigned builders
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.person_outline,
                            size: 13, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 6),
                      task.assignedBuilderIds.isEmpty
                          ? Text('No builder assigned',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange[400]))
                          : Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: task.assignedBuilderIds
                                    .map((id) => FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(id)
                                              .get(),
                                          builder: (context, snapshot) {
                                            final name = snapshot.hasData &&
                                                    snapshot.data!.exists
                                                ? (snapshot.data!.data()
                                                        as Map<String,
                                                            dynamic>)['name']
                                                    as String? ??
                                                    id
                                                : id;
                                            return Text(
                                              name,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500]),
                                            );
                                          },
                                        ))
                                    .toList(),
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Scheduled dates as chips ───────────────────────────
                  if (dates.isEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text('Not scheduled',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange[400])),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text(
                              '${dates.length} working day${dates.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: dates.map((iso) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF6C63FF)
                                      .withOpacity(0.2)),
                            ),
                            child: Text(
                              _formatScheduledDate(iso),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w500),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),

                  // Guide price range
                  Row(
                    children: [
                      Icon(Icons.currency_pound,
                          size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        'Guide: £${task.guidePriceMin.toStringAsFixed(0)} – £${task.guidePriceMax.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),

                  // ── Quote & Agreed prices ──────────────────────────────
                  if (task.hasQuote) ...[
                    const SizedBox(height: 6),
                    if (task.agreedTotal != null &&
                        task.agreedTotal! > 0 &&
                        task.quoteTotal != task.agreedTotal) ...[
                      Row(
                        children: [
                          Icon(Icons.fiber_new_rounded,
                              size: 14, color: const Color(0xFFFF6B6B)),
                          const SizedBox(width: 4),
                          Text(
                            'New Quote: £${(task.quoteTotal ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                          const Spacer(),
                          if (task.quoteStatus != null)
                            _QuoteStatusBadge(status: task.quoteStatus!),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 13, color: const Color(0xFF43C59E)),
                          const SizedBox(width: 6),
                          Text(
                            'Agreed: £${(task.agreedTotal ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF43C59E),
                            ),
                          ),
                          const Spacer(),
                          if (task.quoteStatus != null)
                            _QuoteStatusBadge(status: task.quoteStatus!),
                        ],
                      ),
                    ],

                    if (task.quoteStatus == 'declined' &&
                        task.quoteDeclineReason != null &&
                        task.quoteDeclineReason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.message_outlined,
                              size: 11, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.quoteDeclineReason!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // ── Negotiation Section ──────────────────────────────────────
            if (_hasNegotiation) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.06),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.handshake_outlined,
                            size: 16, color: Color(0xFF4ECDC4)),
                        const SizedBox(width: 6),
                        const Text(
                          'Negotiation Request',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4ECDC4),
                          ),
                        ),
                        const Spacer(),
                        if (_negotiation['submittedAt'] != null)
                          Text(
                            _formatDate(_negotiation['submittedAt']),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _negotiationFeeBox(
                            label: 'Current Fee',
                            amount:
                                '£${(_negotiation['currentFee'] as num?)?.toStringAsFixed(0) ?? task.guidePrice.toStringAsFixed(0)}',
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _negotiationFeeBox(
                            label: 'Requested Fee',
                            amount:
                                '£${(_negotiation['requestedFee'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            color: const Color(0xFF4ECDC4),
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _negotiation['reason'] ?? '',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _acceptNegotiation(context),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF43C59E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Accept',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _counterOffer(context),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.swap_horiz_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Counter',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _declineNegotiation(context),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Decline',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _negotiationFeeBox({
    required String label,
    required String amount,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? color.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: highlight ? color : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PriceColumn — label + amount stacked vertically
// ─────────────────────────────────────────────────────────────────────────────

class _PriceColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _PriceColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.currency_pound, size: 10, color: color),
            Text(
              amount.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuoteStatusBadge — compact inline badge
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteStatusBadge extends StatelessWidget {
  final String status;
  const _QuoteStatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'accepted': return const Color(0xFF43C59E);
      case 'declined': return const Color(0xFFFF6B6B);
      default:         return const Color(0xFFFFB347);
    }
  }

  String get _label {
    switch (status) {
      case 'accepted': return 'Approved';
      case 'declined': return 'Declined';
      default:         return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuoteStatusRow — shows quote status + decline reason if any
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteStatusRow extends StatelessWidget {
  final String status;
  final String? declineReason;

  const _QuoteStatusRow({required this.status, this.declineReason});

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
        return 'Quote Approved';
      case 'declined':
        return 'Quote Declined';
      default:
        return 'Quote Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: _color),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ],
        ),
        if (status == 'declined' &&
            declineReason != null &&
            declineReason!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.message_outlined,
                  size: 11, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  declineReason!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}