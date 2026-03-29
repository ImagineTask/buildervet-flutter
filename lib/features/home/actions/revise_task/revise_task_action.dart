import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../base_action_tile.dart';

class ReviseTaskAction extends BaseActionTile {
  const ReviseTaskAction({super.key, required super.project});

  @override
  bool get isDisabled =>
      project.isDone ||
      project.isDenied ||
      project.isUnassigned;

  @override
  String get disabledReason {
    if (project.isDone) return 'Task is completed';
    if (project.isDenied) return 'Task has been denied';
    if (project.isUnassigned) return 'Task has not been assigned yet';
    return '';
  }

  @override
  IconData get icon => Icons.edit_note_outlined;

  @override
  String get label => 'Revise\nTask';

  @override
  Color get color => const Color(0xFF4ECDC4);

  @override
  void onTap(BuildContext context) {
    if (isDisabled) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviseSheet(task: project),
    );
  }
}

// ─────────────────────────────────────────────
// Revise Bottom Sheet
// ─────────────────────────────────────────────
class _ReviseSheet extends StatefulWidget {
  final dynamic task;

  const _ReviseSheet({required this.task});

  @override
  State<_ReviseSheet> createState() => _ReviseSheetState();
}

class _ReviseSheetState extends State<_ReviseSheet> {
  final _requestedFeeController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _selectedReason;
  bool _isSaving = false;

  // Revision type
  bool _reviseFee = true;
  bool _reviseDeadline = false;

  // Deadline
  Set<DateTime> _selectedDates = {};
  List<DateTimeRange> _occupiedRanges = [];
  bool _isLoadingOccupied = false;

  final List<String> _reasonOptions = [
    'Scope is larger than expected',
    'Materials cost has increased',
    'Access is more difficult than described',
    'Additional equipment required',
    'Timeline is too tight',
    'Travel costs not accounted for',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.task.guidePrice > 0) {
      _requestedFeeController.text =
          widget.task.guidePrice.toStringAsFixed(0);
    }
    final savedDates =
        List<dynamic>.from(widget.task.metadata['scheduledDates'] ?? []);
    _selectedDates = savedDates
        .map((d) => DateTime.tryParse(d.toString()))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
  }

  @override
  void dispose() {
    _requestedFeeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadOccupiedRanges() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingOccupied = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedBuilderIds', arrayContains: currentUser.uid)
          .where('taskType', isEqualTo: 'task')
          .get();

      final ranges = <DateTimeRange>[];
      for (final doc in snap.docs) {
        if (doc.id == widget.task.id) continue;
        final d = doc.data();
        final metadata = Map<String, dynamic>.from(d['metadata'] ?? {});
        final savedDates =
            List<dynamic>.from(metadata['scheduledDates'] ?? []);
        for (final dateStr in savedDates) {
          final date = DateTime.tryParse(dateStr.toString());
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            ranges.add(DateTimeRange(
              start: normalized,
              end: normalized.add(const Duration(hours: 23)),
            ));
          }
        }
      }
      setState(() {
        _occupiedRanges = ranges;
        _isLoadingOccupied = false;
      });
    } catch (e) {
      setState(() => _isLoadingOccupied = false);
    }
  }

  bool _isOccupied(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    for (final r in _occupiedRanges) {
      final rStart = DateTime(r.start.year, r.start.month, r.start.day);
      final rEnd = DateTime(r.end.year, r.end.month, r.end.day);
      if (!normalized.isBefore(rStart) && !normalized.isAfter(rEnd)) {
        return true;
      }
    }
    return false;
  }

  DateTime? get _startDate => _selectedDates.isEmpty
      ? null
      : _selectedDates.reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get _endDate => _selectedDates.isEmpty
      ? null
      : _selectedDates.reduce((a, b) => a.isAfter(b) ? a : b);

  void _toggleDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      if (_selectedDates.contains(normalized)) {
        _selectedDates.remove(normalized);
      } else {
        _selectedDates.add(normalized);
      }
    });
  }

  Future<void> _submit() async {
    if (!_reviseFee && !_reviseDeadline) {
      _showSnack('Please select at least one revision type');
      return;
    }
    if (_selectedReason == null) {
      _showSnack('Please select a reason');
      return;
    }
    if (_reviseFee && _requestedFeeController.text.trim().isEmpty) {
      _showSnack('Please enter your requested fee');
      return;
    }
    if (_reviseDeadline && _selectedDates.isEmpty) {
      _showSnack('Please select at least one working date');
      return;
    }
    if (_selectedReason == 'Other' &&
        _reasonController.text.trim().isEmpty) {
      _showSnack('Please describe your reason');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final firestore = FirebaseFirestore.instance;
      final taskRef = firestore.collection('tasks').doc(widget.task.id);
      final requestedFee =
          double.tryParse(_requestedFeeController.text.trim()) ?? 0;
      final reason = _selectedReason == 'Other'
          ? _reasonController.text.trim()
          : _selectedReason!;
      final now = DateTime.now().toUtc().toIso8601String();
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';

      final batch = firestore.batch();

      final Map<String, dynamic> updates = {
        'status': 'revising',
        'updatedAt': now,
        'actionSpace': ['accept_task', 'deny_task', 'revise_task'],
        'metadata.revision': {
          'reason': reason,
          'submittedAt': now,
          'reviseFee': _reviseFee,
          'reviseDeadline': _reviseDeadline,
          if (_reviseFee) ...{
            'requestedFee': requestedFee,
            'currentFee': widget.task.guidePrice,
          },
          if (_reviseDeadline) ...{
            'requestedDates': _selectedDates
                .map((d) => d.toIso8601String())
                .toList(),
            'currentStartTime': widget.task.startTime.toIso8601String(),
            'currentEndTime': widget.task.endTime.toIso8601String(),
            'currentDurationDays': widget.task.durationDays,
          },
        },
      };

      if (_reviseDeadline && _selectedDates.isNotEmpty) {
        final sortedDates = _selectedDates.toList()..sort();
        updates['metadata.scheduledDates'] =
            sortedDates.map((d) => d.toIso8601String()).toList();
        updates['startTime'] = Timestamp.fromDate(sortedDates.first);
        updates['endTime'] = Timestamp.fromDate(sortedDates.last);
        updates['durationDays'] = _selectedDates.length;
      }

      if (_reviseFee) {
        updates['guidePrice'] = requestedFee;
      }

      batch.update(taskRef, updates);

      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'task_revised',
        'timestamp': now,
        'actorId': currentUser?.uid ?? widget.task.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'builder',
        'data': {
          'previousStatus': widget.task.status,
          'newStatus': 'revising',
          'reason': reason,
          'reviseFee': _reviseFee,
          'reviseDeadline': _reviseDeadline,
          if (_reviseFee) ...{
            'requestedFee': requestedFee,
            'currentFee': widget.task.guidePrice,
          },
          if (_reviseDeadline) ...{
            'requestedDates': _selectedDates
                .map((d) => d.toIso8601String())
                .toList(),
            'currentDurationDays': widget.task.durationDays,
          },
        },
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revision request sent to project owner'),
            backgroundColor: Color(0xFF4ECDC4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Failed to send. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Revise Task',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_note_outlined,
                            size: 14, color: Color(0xFF4ECDC4)),
                        SizedBox(width: 4),
                        Text(
                          'Revising',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4ECDC4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.task.taskName,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── What to revise ────────────────────────────────
                    _label('What would you like to revise?'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _reviseToggle(
                            icon: Icons.currency_pound,
                            label: 'Fee',
                            selected: _reviseFee,
                            onTap: () =>
                                setState(() => _reviseFee = !_reviseFee),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _reviseToggle(
                            icon: Icons.calendar_today_outlined,
                            label: 'Deadline',
                            selected: _reviseDeadline,
                            onTap: () async {
                              setState(
                                  () => _reviseDeadline = !_reviseDeadline);
                              if (_reviseDeadline &&
                                  _occupiedRanges.isEmpty) {
                                await _loadOccupiedRanges();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Fee section ───────────────────────────────────
                    if (_reviseFee) ...[
                      _label('Requested Fee'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _feeInfoItem(
                                label: 'Current Fee',
                                value:
                                    '£${widget.task.guidePrice.toStringAsFixed(0)}',
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 36,
                                color: Colors.grey[300]),
                            Expanded(
                              child: _feeInfoItem(
                                label: 'Guide Range',
                                value:
                                    '£${widget.task.guidePriceMin.toStringAsFixed(0)} – £${widget.task.guidePriceMax.toStringAsFixed(0)}',
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _requestedFeeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter requested fee',
                          prefixIcon: const Icon(Icons.currency_pound,
                              color: Color(0xFF4ECDC4)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF4ECDC4), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Deadline section ──────────────────────────────
                    if (_reviseDeadline) ...[
                      _label('Requested Working Dates'),
                      const SizedBox(height: 4),
                      Text(
                        'Tap dates to select your preferred working days',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 12),

                      // Current schedule + duration reference
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Schedule',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDate(widget.task.startTime)} – ${_formatDate(widget.task.endTime)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 36,
                                color: Colors.grey[300]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Duration',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 12,
                                          color: Color(0xFF4ECDC4)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.task.durationDays} day${widget.task.durationDays > 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E),
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

                      // Legend
                      Row(
                        children: [
                          _legendItem(
                              const Color(0xFF4ECDC4), 'Selected'),
                          const SizedBox(width: 16),
                          _legendItem(Colors.grey.shade400, 'Occupied'),
                          const SizedBox(width: 16),
                          _legendItem(
                              Colors.grey.shade200, 'Unavailable'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isLoadingOccupied)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                color: Color(0xFF4ECDC4)),
                          ),
                        )
                      else
                        _ReviseCalendar(
                          selectedDates: _selectedDates,
                          isOccupied: _isOccupied,
                          onDayTap: _toggleDate,
                        ),

                      // Selected days summary with comparison
                      if (_selectedDates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4)
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Selected days
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.check_circle_outline,
                                              size: 13,
                                              color: Color(0xFF4ECDC4)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_selectedDates.length} day${_selectedDates.length > 1 ? 's' : ''} selected',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4ECDC4),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Expected days + badge
                                      Row(
                                        children: [
                                          Icon(
                                              Icons
                                                  .calendar_today_outlined,
                                              size: 13,
                                              color: Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${widget.task.durationDays} day${widget.task.durationDays > 1 ? 's' : ''} expected',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _selectedDates
                                                          .length ==
                                                      widget.task
                                                          .durationDays
                                                  ? Colors.grey
                                                      .withOpacity(0.1)
                                                  : _selectedDates.length >
                                                          widget.task
                                                              .durationDays
                                                      ? const Color(
                                                              0xFFFFB347)
                                                          .withOpacity(0.15)
                                                      : const Color(
                                                              0xFF6C63FF)
                                                          .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _selectedDates.length ==
                                                      widget.task
                                                          .durationDays
                                                  ? 'same as expected'
                                                  : _selectedDates.length >
                                                          widget.task
                                                              .durationDays
                                                      ? '+${_selectedDates.length - widget.task.durationDays} more'
                                                      : '-${widget.task.durationDays - _selectedDates.length} less',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _selectedDates
                                                            .length ==
                                                        widget.task
                                                            .durationDays
                                                    ? Colors.grey
                                                    : _selectedDates
                                                                .length >
                                                            widget.task
                                                                .durationDays
                                                        ? const Color(
                                                            0xFFFFB347)
                                                        : const Color(
                                                            0xFF6C63FF),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedDates.clear()),
                                    child: const Text('Clear',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red)),
                                  ),
                                ],
                              ),
                              if (_startDate != null &&
                                  _endDate != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'From ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],

                    // ── Reason selector ───────────────────────────────
                    _label('Reason for Revision'),
                    const SizedBox(height: 10),
                    ...(_reasonOptions.map((reason) {
                      final isSelected = _selectedReason == reason;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedReason = reason),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4ECDC4).withOpacity(0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4ECDC4)
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? const Color(0xFF4ECDC4)
                                    : Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.grey[600],
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })).toList(),

                    // Other reason text field
                    if (_selectedReason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe your reason...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF4ECDC4), width: 2),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Send Revision Request',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
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

  Widget _reviseToggle({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4ECDC4).withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? const Color(0xFF4ECDC4) : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected
                    ? const Color(0xFF4ECDC4)
                    : Colors.grey[400],
                size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? const Color(0xFF4ECDC4)
                    : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
      );

  Widget _feeInfoItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

// ─────────────────────────────────────────────
// Revise Calendar with occupied dates
// ─────────────────────────────────────────────
class _ReviseCalendar extends StatefulWidget {
  final Set<DateTime> selectedDates;
  final bool Function(DateTime) isOccupied;
  final void Function(DateTime) onDayTap;

  const _ReviseCalendar({
    required this.selectedDates,
    required this.isOccupied,
    required this.onDayTap,
  });

  @override
  State<_ReviseCalendar> createState() => _ReviseCalendarState();
}

class _ReviseCalendarState extends State<_ReviseCalendar> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
        _focusedMonth.year, _focusedMonth.month);
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() => _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
              icon: const Icon(Icons.chevron_left,
                  color: Color(0xFF4ECDC4)),
            ),
            Text(_monthLabel(_focusedMonth),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E))),
            IconButton(
              onPressed: () => setState(() => _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
              icon: const Icon(Icons.chevron_right,
                  color: Color(0xFF4ECDC4)),
            ),
          ],
        ),
        Row(
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400])),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox();
            final day = DateTime(_focusedMonth.year, _focusedMonth.month,
                index - firstWeekday + 1);
            final normalized = DateTime(day.year, day.month, day.day);
            final isSelected = widget.selectedDates.contains(normalized);
            final isOccupied = widget.isOccupied(normalized);
            final isPast = day.isBefore(
                DateTime(today.year, today.month, today.day));
            final isToday = DateUtils.isSameDay(day, today);
            final isDisabled = isOccupied || isPast;

            Color bgColor = Colors.transparent;
            Color textColor = const Color(0xFF1A1A2E);

            if (isSelected) {
              bgColor = const Color(0xFF4ECDC4);
              textColor = Colors.white;
            } else if (isOccupied) {
              bgColor = Colors.grey.shade300;
              textColor = Colors.grey.shade500;
            } else if (isPast) {
              textColor = Colors.grey.shade300;
            }

            return GestureDetector(
              onTap:
                  isDisabled ? null : () => widget.onDayTap(normalized),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected && !isOccupied
                      ? Border.all(
                          color: const Color(0xFF4ECDC4), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}