import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../base_action_tile.dart';

class ReviseTaskAction extends BaseActionTile {
  const ReviseTaskAction({super.key, required super.project});

  @override
  bool get isDisabled =>
      project.status == 'done' ||
      project.status == 'denied' ||
      project.status == 'unassigned';

  @override
  String get disabledReason {
    if (project.status == 'done') return 'Task is completed';
    if (project.status == 'denied') return 'Task has been denied';
    if (project.status == 'unassigned') return 'Task has not been assigned yet';
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
      _requestedFeeController.text = widget.task.guidePrice.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _requestedFeeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      _showSnack('Please select a reason');
      return;
    }
    if (_requestedFeeController.text.trim().isEmpty) {
      _showSnack('Please enter your requested fee');
      return;
    }
    if (_selectedReason == 'Other' && _reasonController.text.trim().isEmpty) {
      _showSnack('Please describe your reason');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final firestore = FirebaseFirestore.instance;
      final taskRef = firestore.collection('tasks').doc(widget.task.id);
      final requestedFee = double.tryParse(_requestedFeeController.text.trim()) ?? 0;
      final reason = _selectedReason == 'Other'
          ? _reasonController.text.trim()
          : _selectedReason!;
      final now = DateTime.now().toUtc().toIso8601String();
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';

      final batch = firestore.batch();

      // 1. Update task
      batch.update(taskRef, {
        'status': 'revising',
        'updatedAt': now,
        'actionSpace': ['accept_task', 'deny_task', 'revise_task'],
        'metadata.revision': {
          'requestedFee': requestedFee,
          'currentFee': widget.task.guidePrice,
          'reason': reason,
          'submittedAt': now,
        },
      });

      // 2. Write event to subcollection
      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'task_revised',
        'timestamp': now,
        'actorId': currentUser?.uid ?? widget.task.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'builder', // builder is requesting the revision
        'data': {
          'previousStatus': widget.task.status,
          'newStatus': 'revising',
          'requestedFee': requestedFee,
          'currentFee': widget.task.guidePrice,
          'reason': reason,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_note_outlined, size: 14, color: Color(0xFF4ECDC4)),
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
                    // Current fee vs guide price range
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _feeInfoItem(
                              label: 'Current Fee',
                              value: '£${widget.task.guidePrice.toStringAsFixed(0)}',
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.grey[300]),
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
                    const SizedBox(height: 24),

                    // Reason selector
                    _label('Reason for Revision'),
                    const SizedBox(height: 10),
                    ...(_reasonOptions.map((reason) {
                      final isSelected = _selectedReason == reason;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedReason = reason),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4ECDC4).withOpacity(0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF4ECDC4) : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? const Color(0xFF4ECDC4) : Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected ? const Color(0xFF1A1A2E) : Colors.grey[600],
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Requested fee
                    _label('Requested Fee'),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the fee you would accept for this task',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _requestedFeeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(Icons.currency_pound, color: Color(0xFF4ECDC4)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Send Revision Request',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}