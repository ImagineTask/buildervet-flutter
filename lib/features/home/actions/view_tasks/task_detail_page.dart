import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../schedule_work/task_schedule_detail_page.dart';
import '../review_quotes/quote_management_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskDetailPage
// ─────────────────────────────────────────────────────────────────────────────

class TaskDetailPage extends StatefulWidget {
  final TaskModel task;
  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with TickerProviderStateMixin {
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Local mutable copy of the task ────────────────────────────────────────
  late TaskModel _task;

  bool _editMode = false;
  bool _isSaving = false;
  DateTime? _editStartDate;
  DateTime? _editEndDate;

  Color get _statusColor {
    switch (_task.status) {
      case 'draft':              return const Color(0xFF9E9E9E);
      case 'pending_acceptance': return const Color(0xFFFFB347);
      case 'active':             return const Color(0xFF6C63FF);
      case 'negotiating':        return const Color(0xFF4ECDC4);
      case 'done':               return const Color(0xFF43C59E);
      case 'denied':             return const Color(0xFFFF6B6B);
      default:                   return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (_task.status) {
      case 'draft':              return 'Draft';
      case 'pending_acceptance': return 'Awaiting Acceptance';
      case 'active':             return 'Active';
      case 'negotiating':        return 'Negotiating';
      case 'done':               return 'Done';
      case 'denied':             return 'Denied';
      default:                   return _task.status;
    }
  }

  bool get _hasNegotiation =>
      _task.metadata['negotiation'] != null &&
      _task.status == 'negotiating';

  Map<String, dynamic> get _negotiation =>
      Map<String, dynamic>.from(_task.metadata['negotiation'] ?? {});

  List<String> get _actionSpace =>
      List<String>.from(_task.metadata['actionSpace'] ?? []);

  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('d MMM yyyy · HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) { return '—'; }
  }

  @override
  void initState() {
    super.initState();

    _task = widget.task;

    _descriptionController = TextEditingController(text: _task.description);
    _durationController = TextEditingController(
        text: (_task.metadata['durationDays'] ?? '').toString());

    final rawStart = _task.metadata['startTime'] as String?;
    final rawEnd   = _task.metadata['endTime']   as String?;
    if (rawStart != null) _editStartDate = DateTime.tryParse(rawStart)?.toLocal();
    if (rawEnd   != null) _editEndDate   = DateTime.tryParse(rawEnd)?.toLocal();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _durationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Reload task from Firestore after returning from schedule page ──────────
  Future<void> _reloadTask() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(_task.id)
          .get();
      if (snap.exists && mounted) {
        setState(() => _task = TaskModel.fromFirestore(snap));
      }
    } catch (_) {}
  }

  void _enterEditMode() => setState(() => _editMode = true);

  void _cancelEdit() {
    _descriptionController.text = _task.description;
    _durationController.text =
        (_task.metadata['durationDays'] ?? '').toString();
    final rawStart = _task.metadata['startTime'] as String?;
    final rawEnd   = _task.metadata['endTime']   as String?;
    _editStartDate =
        rawStart != null ? DateTime.tryParse(rawStart)?.toLocal() : null;
    _editEndDate =
        rawEnd != null ? DateTime.tryParse(rawEnd)?.toLocal() : null;
    setState(() => _editMode = false);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'description': _descriptionController.text.trim(),
        'updatedAt':   FieldValue.serverTimestamp(),
      };
      final duration = int.tryParse(_durationController.text);
      if (duration != null) updates['metadata.durationDays'] = duration;
      if (_editStartDate != null)
        updates['metadata.startTime'] = _editStartDate!.toUtc().toIso8601String();
      if (_editEndDate != null)
        updates['metadata.endTime'] = _editEndDate!.toUtc().toIso8601String();

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(_task.id)
          .update(updates);

      if (mounted) {
        setState(() { _editMode = false; _isSaving = false; });
        _showSnack('Changes saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Failed to save. Try again.', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: isError ? Colors.red : const Color(0xFF43C59E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: const Color(0xFFF9F9FF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildDescriptionSection(),
                  const SizedBox(height: 16),
                  _buildPriceSection(),
                  const SizedBox(height: 16),
                  _buildAssignedBuilderSection(),
                  if (_hasNegotiation) ...[
                    const SizedBox(height: 16),
                    _buildNegotiationSection(),
                  ],
                  if (_actionSpace.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildActionSpaceSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildAuditSection(),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFab(),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.06),
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Color(0xFF1A1A2E)),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _task.taskName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_task.contractorType != null)
              Text(_task.contractorType!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab() {
    if (_editMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _cancelEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveChanges,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF5A52E8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Save & Lock',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 56,
        child: GestureDetector(
          onTap: _enterEditMode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6C63FF)),
                SizedBox(width: 8),
                Text('Edit',
                    style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Status Banner ─────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final taskOrder = _task.metadata['taskOrder'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _statusColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_statusLabel,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _statusColor)),
          const Spacer(),
          if (taskOrder != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text('Task #$taskOrder',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────

  Widget _buildDescriptionSection() {
    return _SectionCard(
      title: 'Description',
      icon: Icons.notes_rounded,
      editMode: _editMode,
      child: _editMode
          ? TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[700], height: 1.5),
              decoration: _inputDeco('Describe the task...'),
            )
          : Text(
              _task.description.isEmpty
                  ? 'No description provided.'
                  : _task.description,
              style: TextStyle(
                  fontSize: 14,
                  color: _task.description.isEmpty
                      ? Colors.grey[400]
                      : Colors.grey[600],
                  height: 1.6,
                  fontStyle: _task.description.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal),
            ),
    );
  }

  // ── Price ─────────────────────────────────────────────────────────────────

  Widget _buildPriceSection() {
    final hasQuote = _task.hasQuote;
    final quoteTotal = _task.quoteTotal ?? 0;
    final agreedTotal = _task.agreedTotal ?? 0;
    final isNewQuote =
        hasQuote && agreedTotal > 0 && quoteTotal != agreedTotal;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteManagementPage(
            projectId: _task.parentTaskId ?? _task.taskId,
            projectName: _task.taskName,
          ),
        ),
      ),
      child: _SectionCard(
        title: 'Price',
        icon: Icons.currency_pound_rounded,
        accentColor: const Color(0xFF6C63FF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Guide Range',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text(
                    '£${_task.guidePriceMin.toStringAsFixed(0)} – £${_task.guidePriceMax.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (hasQuote) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isNewQuote
                      ? const Color(0xFFFF6B6B).withOpacity(0.05)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: isNewQuote
                      ? Border.all(
                          color: const Color(0xFFFF6B6B).withOpacity(0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.request_quote_outlined,
                              size: 14,
                              color: isNewQuote
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text('Quote',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ]),
                        Text(
                          '£${quoteTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isNewQuote
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.check_circle_outline,
                              size: 14,
                              color: isNewQuote
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF43C59E)),
                          const SizedBox(width: 6),
                          Text('Agreed',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ]),
                        Text(
                          '£${agreedTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isNewQuote
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF43C59E),
                          ),
                        ),
                      ],
                    ),
                    if (isNewQuote) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 13, color: Color(0xFFFF6B6B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'New quote submitted — please review and make a decision.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_task.quoteStatus != null) ...[
                const SizedBox(height: 8),
                _QuoteStatusChip(
                  status: _task.quoteStatus!,
                  declineReason: _task.quoteDeclineReason,
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text('No quote submitted yet',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Assigned Builder ──────────────────────────────────────────────────────
  // Uses assignedBuilderIds which is saved by TaskScheduleDetailPage.
  // Fetches each builder's name from the users collection.

  Widget _buildAssignedBuilderSection() {
    final builderIds = _task.assignedBuilderIds;
    final scheduledDates =
        List<dynamic>.from(_task.metadata['scheduledDates'] ?? []);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskScheduleDetailPage(task: _task),
          ),
        );
        await _reloadTask();
      },
      child: _SectionCard(
        title: 'Assigned Builder',
        icon: Icons.person_outline_rounded,
        accentColor: const Color(0xFF43C59E),
        editMode: _editMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Builder list ─────────────────────────────────────────
            if (builderIds.isEmpty)
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.orange[300]),
                  const SizedBox(width: 6),
                  Text('No builder assigned yet',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[400])),
                ],
              )
            else
              ...builderIds.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(id)
                        .get(),
                    builder: (context, snapshot) {
                      final name = snapshot.hasData && snapshot.data!.exists
                          ? (snapshot.data!.data()
                                  as Map<String, dynamic>)['name']
                              as String? ??
                              id
                          : id;
                      final initial =
                          name.isNotEmpty ? name[0].toUpperCase() : '?';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF43C59E).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  const Color(0xFF43C59E).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  const Color(0xFF43C59E).withOpacity(0.15),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                    color: Color(0xFF43C59E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1A1A2E),
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Scheduled dates ──────────────────────────────────────
            if (scheduledDates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(
                    '${scheduledDates.length} day${scheduledDates.length > 1 ? 's' : ''} scheduled',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: scheduledDates
                    .map((date) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF6C63FF)
                                    .withOpacity(0.2)),
                          ),
                          child: Text(
                            date.toString(),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w500),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Negotiation ───────────────────────────────────────────────────────────

  Widget _buildNegotiationSection() {
    return _SectionCard(
      title: 'Negotiation Request',
      icon: Icons.handshake_outlined,
      accentColor: const Color(0xFF4ECDC4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _feeBox(
                      'Current',
                      '£${(_negotiation['currentFee'] as num?)?.toStringAsFixed(0) ?? _task.guidePrice.toStringAsFixed(0)}',
                      false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Colors.grey[400]),
              ),
              Expanded(
                  child: _feeBox(
                      'Requested',
                      '£${(_negotiation['requestedFee'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      true)),
            ],
          ),
          if (_negotiation['reason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      size: 16, color: Colors.grey[300]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_negotiation['reason'],
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feeBox(String label, String amount, bool highlight) {
    const color = Color(0xFF4ECDC4);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? color.withOpacity(0.25) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(amount,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highlight ? color : const Color(0xFF1A1A2E))),
        ],
      ),
    );
  }

  // ── Action Space ──────────────────────────────────────────────────────────

  Widget _buildActionSpaceSection() {
    final actionMeta = <String, _ActionMeta>{
      'accept_task': _ActionMeta(
          label: 'Accept Task',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF43C59E)),
      'deny_task': _ActionMeta(
          label: 'Deny Task',
          icon: Icons.cancel_outlined,
          color: const Color(0xFFFF6B6B)),
      'negotiate_task': _ActionMeta(
          label: 'Negotiate',
          icon: Icons.handshake_outlined,
          color: const Color(0xFF4ECDC4)),
    };

    return _SectionCard(
      title: 'Available Actions',
      icon: Icons.bolt_rounded,
      accentColor: const Color(0xFF6C63FF),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _actionSpace.map((action) {
          final meta = actionMeta[action];
          if (meta == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: meta.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: meta.color.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meta.icon, size: 15, color: meta.color),
                  const SizedBox(width: 6),
                  Text(meta.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: meta.color)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Audit ─────────────────────────────────────────────────────────────────

  Widget _buildAuditSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 12, color: Colors.grey[350]),
          const SizedBox(width: 4),
          Text('Created ',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          Text(
            _formatDateTime(_task.metadata['createdAt'] as String?),
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Icon(Icons.edit_outlined, size: 12, color: Colors.grey[350]),
          const SizedBox(width: 4),
          Text('Updated ',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          Text(
            _formatDateTime(_task.metadata['updatedAt'] as String?),
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuoteStatusChip
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteStatusChip extends StatelessWidget {
  final String status;
  final String? declineReason;

  const _QuoteStatusChip({required this.status, this.declineReason});

  Color get _color {
    switch (status) {
      case 'accepted': return const Color(0xFF43C59E);
      case 'declined': return const Color(0xFFFF6B6B);
      default:         return const Color(0xFFFFB347);
    }
  }

  String get _label {
    switch (status) {
      case 'accepted': return 'Quote Approved';
      case 'declined': return 'Quote Declined';
      default:         return 'Quote Pending';
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
            Text(_label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _color)),
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
                child: Text(declineReason!,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting classes
// ─────────────────────────────────────────────────────────────────────────────

class _ActionMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _ActionMeta(
      {required this.label, required this.icon, required this.color});
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;
  final bool editMode;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
    this.editMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF6C63FF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: editMode
            ? Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(editMode ? 0.06 : 0.04),
            blurRadius: editMode ? 14 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                if (editMode) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Editable',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}