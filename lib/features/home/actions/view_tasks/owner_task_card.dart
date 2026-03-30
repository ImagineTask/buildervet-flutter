import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import 'task_detail_page.dart';

class OwnerTaskCard extends StatefulWidget {
  final TaskModel task;
  final int? orderNumber;
  final bool reorderMode;

  const OwnerTaskCard({
    super.key,
    required this.task,
    this.orderNumber,
    this.reorderMode = false,
  });

  @override
  State<OwnerTaskCard> createState() => _OwnerTaskCardState();
}

class _OwnerTaskCardState extends State<OwnerTaskCard> {
  bool _showAllDates = false;
  static const int _maxVisibleDates = 3;

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool get _hasRevision =>
      widget.task.metadata['revision'] != null &&
      widget.task.status == 'revising';

  Map<String, dynamic> get _revision =>
      Map<String, dynamic>.from(widget.task.metadata['revision'] ?? {});

  bool get _revisesFee => _revision['reviseFee'] == true;
  bool get _revisesDeadline => _revision['reviseDeadline'] == true;

  List<String> get _scheduledDates {
    final dates = widget.task.metadata['scheduledDates'];
    if (dates == null) return [];
    return List<String>.from(dates as List);
  }

  List<String> get _requestedDates {
    final dates = _revision['requestedDates'];
    if (dates == null) return [];
    return List<String>.from(dates as List);
  }

  Color get _statusColor {
    switch (widget.task.status) {
      case 'unassigned':
        return const Color(0xFFFF6B6B);
      case 'pending_acceptance':
        return const Color(0xFFFFB347);
      case 'active':
        return const Color(0xFF6C63FF);
      case 'revising':
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
      case 'unassigned':
        return 'Unassigned';
      case 'pending_acceptance':
        return 'Awaiting';
      case 'active':
        return 'Active';
      case 'revising':
        return 'Revising';
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

  void _copyTaskId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.task.taskId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task ID copied: ${widget.task.taskId}'),
        backgroundColor: const Color(0xFF6C63FF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Accept revision ──────────────────────────────────────────────────────
  Future<void> _acceptRevision(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final currentUser = FirebaseAuth.instance.currentUser;
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id);
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';

      final batch = FirebaseFirestore.instance.batch();

      final Map<String, dynamic> updates = {
        'status': 'pending_acceptance',
        'actionSpace': ['accept_task', 'deny_task', 'revise_task'],
        'updatedAt': now,
        'metadata.revision.resolvedAt': now,
        'metadata.revision.resolution': 'accepted',
      };

      if (_revisesFee) {
        final requestedFee =
            (_revision['requestedFee'] as num?)?.toDouble() ?? 0;
        updates['guidePrice'] = requestedFee;
      }

      if (_revisesDeadline && _requestedDates.isNotEmpty) {
        final sortedDates = _requestedDates
            .map((d) => DateTime.tryParse(d))
            .whereType<DateTime>()
            .toList()
          ..sort();
        updates['metadata.scheduledDates'] = _requestedDates;
        updates['startTime'] = Timestamp.fromDate(sortedDates.first);
        updates['endTime'] = Timestamp.fromDate(sortedDates.last);
        updates['durationDays'] = sortedDates.length;
      }

      batch.update(taskRef, updates);

      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'revision_accepted',
        'timestamp': now,
        'actorId': currentUser?.uid ?? widget.task.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'homeowner',
        'data': {
          'previousStatus': 'revising',
          'newStatus': 'pending_acceptance',
          'revisionAccepted': true,
        },
      });

      await batch.commit();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Revision accepted — task sent back to builder'),
          backgroundColor: Color(0xFF43C59E),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to accept revision. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Decline revision ─────────────────────────────────────────────────────
  Future<void> _declineRevision(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Decline Revision',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        content: const Text(
          'The revision will be rejected and the task will go back to the builder with original terms.',
          style: TextStyle(color: Colors.grey),
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

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final currentUser = FirebaseAuth.instance.currentUser;
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id);
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';

      final batch = FirebaseFirestore.instance.batch();

      batch.update(taskRef, {
        'status': 'pending_acceptance',
        'actionSpace': ['accept_task', 'deny_task', 'revise_task'],
        'updatedAt': now,
        'metadata.revision.resolvedAt': now,
        'metadata.revision.resolution': 'declined',
      });

      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'revision_declined',
        'timestamp': now,
        'actorId': currentUser?.uid ?? widget.task.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'homeowner',
        'data': {
          'previousStatus': 'revising',
          'newStatus': 'pending_acceptance',
          'revisionAccepted': false,
        },
      });

      await batch.commit();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Revision declined — original terms kept'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to decline revision. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final dates = _scheduledDates;
    final visibleDates = _showAllDates
        ? dates
        : dates.take(_maxVisibleDates).toList();
    final hiddenCount = dates.length - _maxVisibleDates;

    return GestureDetector(
      // Disable tap and long press in reorder mode
      onTap: widget.reorderMode
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TaskDetailPage(task: task)),
              ),
      onLongPress: widget.reorderMode
          ? null
          : () => _copyTaskId(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: _hasRevision
              ? Border.all(
                  color: const Color(0xFF4ECDC4), width: 1.5)
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
                  // Task name + order number + status
                  Row(
                    children: [
                      if (widget.orderNumber != null) ...[
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${widget.orderNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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

                  // Contractor type + duration days
                  Row(
                    children: [
                      if (task.contractorType != null) ...[
                        Icon(Icons.work_outline,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(task.contractorType!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500])),
                        const SizedBox(width: 12),
                      ],
                      if (task.durationDays > 0) ...[
                        Icon(Icons.timelapse_outlined,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${task.durationDays} day${task.durationDays > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
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
                                  fontSize: 12,
                                  color: Colors.orange[400]))
                          : Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: task.assignedBuilderIds
                                    .map((id) =>
                                        FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore
                                              .instance
                                              .collection('users')
                                              .doc(id)
                                              .get(),
                                          builder: (context, snapshot) {
                                            final name = snapshot
                                                        .hasData &&
                                                    snapshot.data!.exists
                                                ? (snapshot.data!.data()
                                                        as Map<String,
                                                            dynamic>)[
                                                    'name'] as String? ??
                                                    id
                                                : id;
                                            return Text(
                                              name,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey[500]),
                                            );
                                          },
                                        ))
                                    .toList(),
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Scheduled dates — collapsed
                  if (dates.isEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text('Not scheduled',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[400])),
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
                                  fontSize: 12,
                                  color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ...visibleDates.map((iso) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C63FF)
                                        .withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(20),
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
                                )),
                            if (dates.length > _maxVisibleDates)
                              GestureDetector(
                                onTap: widget.reorderMode
                                    ? null
                                    : () => setState(() =>
                                        _showAllDates = !_showAllDates),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.grey
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _showAllDates
                                        ? 'Show less'
                                        : '+$hiddenCount more',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),

                  // Guide price + quote price inline
                  Row(
                    children: [
                      Text(
                        'Guide: ${task.guidePriceMin.toStringAsFixed(0)} – ${task.guidePriceMax.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                      ),
                      if (task.hasQuote &&
                          task.quoteTotal != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 12,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quote: ${task.quoteTotal!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF43C59E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (task.quoteStatus != null)
                          _QuoteStatusBadge(
                              status: task.quoteStatus!),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Revision Section (animated) ───────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _hasRevision
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4)
                            .withOpacity(0.06),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              const Icon(Icons.edit_note_outlined,
                                  size: 16,
                                  color: Color(0xFF4ECDC4)),
                              const SizedBox(width: 6),
                              const Text(
                                'Revision Request',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                              const Spacer(),
                              if (_revision['submittedAt'] != null)
                                Text(
                                  _formatDate(
                                      _revision['submittedAt']),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400]),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Fee revision
                          if (_revisesFee) ...[
                            _sectionLabel('Fee Revision'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoBox(
                                    label: 'Current Fee',
                                    value:
                                        '${(_revision['currentFee'] as num?)?.toStringAsFixed(0) ?? widget.task.guidePrice.toStringAsFixed(0)}',
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _infoBox(
                                    label: 'Requested Fee',
                                    value:
                                        '${(_revision['requestedFee'] as num?)?.toStringAsFixed(0) ?? '0'}',
                                    color: const Color(0xFF4ECDC4),
                                    highlight: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Deadline revision
                          if (_revisesDeadline &&
                              _requestedDates.isNotEmpty) ...[
                            _sectionLabel('Deadline Revision'),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Current: ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: _scheduledDates
                                        .map((iso) => _datechip(iso,
                                            Colors.grey.shade400))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Requested: ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: _requestedDates
                                        .map((iso) => _datechip(iso,
                                            const Color(0xFF4ECDC4)))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Reason
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14,
                                    color: Colors.grey[400]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _revision['reason'] ?? '',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Accept / Decline buttons
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _acceptRevision(context),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFF43C59E),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_rounded,
                                            color: Colors.white,
                                            size: 16),
                                        SizedBox(width: 4),
                                        Text('Accept',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _declineRevision(context),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFFFF6B6B),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.close_rounded,
                                            color: Colors.white,
                                            size: 16),
                                        SizedBox(width: 4),
                                        Text('Decline',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.w600,
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
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      );

  Widget _infoBox({
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? color.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(
            value,
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

  Widget _datechip(String iso, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _formatScheduledDate(iso),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
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

// ─────────────────────────────────────────────
// _QuoteStatusBadge
// ─────────────────────────────────────────────
class _QuoteStatusBadge extends StatelessWidget {
  final String status;
  const _QuoteStatusBadge({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
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