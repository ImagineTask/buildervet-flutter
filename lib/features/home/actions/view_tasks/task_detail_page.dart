import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../schedule_work/task_schedule_detail_page.dart';

class TaskDetailPage extends StatefulWidget {
  final TaskModel task;

  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with TickerProviderStateMixin {
  late TextEditingController _priceController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isSavingPrice = false;
  bool _priceEdited = false;

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color get _statusColor {
    switch (widget.task.status) {
      case 'draft':
        return const Color(0xFF9E9E9E);
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
      case 'draft':
        return 'Draft';
      case 'pending_acceptance':
        return 'Awaiting Acceptance';
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

  bool get _hasNegotiation =>
      widget.task.metadata['negotiation'] != null &&
      widget.task.status == 'negotiating';

  Map<String, dynamic> get _negotiation =>
      Map<String, dynamic>.from(widget.task.metadata['negotiation'] ?? {});

  List<String> get _actionSpace =>
      List<String>.from(widget.task.metadata['actionSpace'] ?? []);

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('EEE d MMM yyyy').format(dt);
    } catch (_) {
      return '—';
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy · HH:mm').format(dt);
    } catch (_) {
      return '—';
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
        text: widget.task.guidePrice.toStringAsFixed(0));

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _priceController.addListener(() {
      final newVal = double.tryParse(_priceController.text);
      setState(() {
        _priceEdited = newVal != null && newVal != widget.task.guidePrice;
      });
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Save price ───────────────────────────────────────────────────────────

  Future<void> _savePrice() async {
    final fee = double.tryParse(_priceController.text);
    if (fee == null) return;

    setState(() => _isSavingPrice = true);
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'guidePrice': fee,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _priceEdited = false;
          _isSavingPrice = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Price updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF43C59E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPrice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update price. Try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  if (widget.task.description.isNotEmpty) ...[
                    _buildDescriptionSection(),
                    const SizedBox(height: 16),
                  ],
                  _buildTimelineSection(),
                  const SizedBox(height: 16),
                  _buildPriceSection(),
                  const SizedBox(height: 16),
                  _buildScheduleSection(),
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
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context) {
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
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.taskName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.task.contractorType != null)
              Text(
                widget.task.contractorType!,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }

  // ── 1 · Status banner ────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final taskOrder = widget.task.metadata['taskOrder'];
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
          Text(
            _statusLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _statusColor,
            ),
          ),
          const Spacer(),
          if (taskOrder != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Task #$taskOrder',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  // ── 2 · Description ──────────────────────────────────────────────────────

  Widget _buildDescriptionSection() {
    return _SectionCard(
      title: 'Description',
      icon: Icons.notes_rounded,
      child: Text(
        widget.task.description,
        style:
            TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6),
      ),
    );
  }

  // ── 3 · Timeline ─────────────────────────────────────────────────────────

  Widget _buildTimelineSection() {
    final startTime = widget.task.metadata['startTime'] as String?;
    final endTime = widget.task.metadata['endTime'] as String?;
    final durationDays = widget.task.metadata['durationDays'];

    return _SectionCard(
      title: 'Timeline',
      icon: Icons.schedule_rounded,
      accentColor: const Color(0xFFFFB347),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dateBox(
                  label: 'Start',
                  value: _formatDate(startTime),
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF43C59E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateBox(
                  label: 'End',
                  value: _formatDate(endTime),
                  icon: Icons.stop_circle_outlined,
                  color: const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          if (durationDays != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.timelapse_rounded,
                      size: 15, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text('Duration',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  const Spacer(),
                  Text(
                    '$durationDays working day${durationDays > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4 · Price ────────────────────────────────────────────────────────────

  Widget _buildPriceSection() {
    return _SectionCard(
      title: 'Price',
      icon: Icons.currency_pound_rounded,
      accentColor: const Color(0xFF6C63FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Guide Range',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
                Text(
                  '£${widget.task.guidePriceMin.toStringAsFixed(0)} – £${widget.task.guidePriceMax.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Agreed Price',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    prefixText: '£',
                    prefixStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                    hintText: '0',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF6C63FF), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedOpacity(
                opacity: _priceEdited ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedScale(
                  scale: _priceEdited ? 1.0 : 0.8,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _priceEdited && !_isSavingPrice
                        ? _savePrice
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isSavingPrice
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text('Save',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_priceEdited)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tap Save to update the agreed price',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── 5 · Builder & Schedule ───────────────────────────────────────────────

  Widget _buildScheduleSection() {
    return _SectionCard(
      title: 'Builder & Schedule',
      icon: Icons.groups_2_outlined,
      accentColor: const Color(0xFF43C59E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.task.assignedBuilderIds.isNotEmpty) ...[
            ...widget.task.assignedBuilderIds.map((id) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF43C59E).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF43C59E)
                              .withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF43C59E)
                              .withOpacity(0.15),
                          child: Text(
                            id.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF43C59E),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(id,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1A1A2E),
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 4),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.orange[300]),
                  const SizedBox(width: 6),
                  Text('No builders assigned yet',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[400])),
                ],
              ),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      TaskScheduleDetailPage(task: widget.task)),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43C59E), Color(0xFF3AB58E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF43C59E).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Assign Builder & Arrange Time',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6 · Negotiation ──────────────────────────────────────────────────────

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
                      '£${(_negotiation['currentFee'] as num?)?.toStringAsFixed(0) ?? widget.task.guidePrice.toStringAsFixed(0)}',
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
    final color = const Color(0xFF4ECDC4);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color:
            highlight ? color.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? color.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[500])),
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

  // ── 7 · Action space ─────────────────────────────────────────────────────

  Widget _buildActionSpaceSection() {
    final Map<String, _ActionMeta> actionMeta = {
      'accept_task': _ActionMeta(
        label: 'Accept Task',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF43C59E),
      ),
      'deny_task': _ActionMeta(
        label: 'Deny Task',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFFF6B6B),
      ),
      'negotiate_task': _ActionMeta(
        label: 'Negotiate',
        icon: Icons.handshake_outlined,
        color: const Color(0xFF4ECDC4),
      ),
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
            onTap: () {
              // TODO: wire up action handlers
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: meta.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: meta.color.withOpacity(0.25)),
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

  // ── 8 · Audit ────────────────────────────────────────────────────────────

  Widget _buildAuditSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 12, color: Colors.grey[350]),
          const SizedBox(width: 4),
          Text('Created ',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[400])),
          Text(
            _formatDateTime(widget.task.metadata['createdAt'] as String?),
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Icon(Icons.edit_outlined, size: 12, color: Colors.grey[350]),
          const SizedBox(width: 4),
          Text('Updated ',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[400])),
          Text(
            _formatDateTime(widget.task.metadata['updatedAt'] as String?),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ActionMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _ActionMeta(
      {required this.label, required this.icon, required this.color});
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF6C63FF);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
              padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}