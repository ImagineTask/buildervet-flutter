import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import '../../../Network/network/models/network_user.dart';
import '../../../Network/network/services/contacts_service.dart';

class TaskScheduleDetailPage extends StatefulWidget {
  final TaskModel task;

  const TaskScheduleDetailPage({super.key, required this.task});

  @override
  State<TaskScheduleDetailPage> createState() =>
      _TaskScheduleDetailPageState();
}

class _TaskScheduleDetailPageState extends State<TaskScheduleDetailPage> {
  final ContactsService _contactsService = ContactsService();

  Set<DateTime> selectedDates = {};
  final TextEditingController _feeController = TextEditingController();
  List<NetworkUser> allContacts = [];
  List<String> selectedBuilderIds = [];
  Map<String, List<DateTimeRange>> occupiedRanges = {};

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedBuilderIds = List.from(widget.task.assignedBuilderIds);
    if (widget.task.guidePrice > 0) {
      _feeController.text = widget.task.guidePrice.toStringAsFixed(0);
    }
    final savedDates =
        List<dynamic>.from(widget.task.metadata['scheduledDates'] ?? []);
    selectedDates = savedDates
        .map((d) => DateTime.tryParse(d.toString()))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contactIds = await _contactsService.streamContactIds().first;
      final users = await Future.wait(
        contactIds.map((uid) => _contactsService.fetchUser(uid)),
      );
      setState(() {
        allContacts = users.whereType<NetworkUser>().toList();
        isLoading = false;
      });
      if (selectedBuilderIds.isNotEmpty) {
        final ranges = await _fetchOccupiedRanges(selectedBuilderIds);
        setState(() => occupiedRanges = ranges);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, List<DateTimeRange>>> _fetchOccupiedRanges(
      List<String> builderIds) async {
    final Map<String, List<DateTimeRange>> result = {};
    for (final uid in builderIds) {
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedBuilderIds', arrayContains: uid)
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
      result[uid] = ranges;
    }
    return result;
  }

  bool _isOccupied(DateTime date) {
    if (selectedBuilderIds.isEmpty) return false;
    final normalized = DateTime(date.year, date.month, date.day);
    for (final uid in selectedBuilderIds) {
      final ranges = occupiedRanges[uid] ?? [];
      for (final r in ranges) {
        final rStart = DateTime(r.start.year, r.start.month, r.start.day);
        final rEnd = DateTime(r.end.year, r.end.month, r.end.day);
        if (!normalized.isBefore(rStart) && !normalized.isAfter(rEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  void _toggleDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      if (selectedDates.contains(normalized)) {
        selectedDates.remove(normalized);
      } else {
        selectedDates.add(normalized);
      }
    });
  }

  DateTime? get _startDate => selectedDates.isEmpty
      ? null
      : selectedDates.reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get _endDate => selectedDates.isEmpty
      ? null
      : selectedDates.reduce((a, b) => a.isAfter(b) ? a : b);

  Future<void> _save() async {
    if (selectedBuilderIds.isEmpty) {
      _showSnack('Please assign at least one builder.', isError: true);
      return;
    }
    if (selectedDates.isEmpty) {
      _showSnack('Please select at least one working date.', isError: true);
      return;
    }

    setState(() => isSaving = true);

    try {
      final fee = double.tryParse(_feeController.text) ?? 0;
      final sortedDates = selectedDates.toList()..sort();
      final dateStrings =
          sortedDates.map((d) => d.toIso8601String()).toList();

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'assignedBuilderIds': selectedBuilderIds,
        'metadata.scheduledDates': dateStrings,
        'scheduledDates': FieldValue.delete(), // clean up root level
        'startTime': Timestamp.fromDate(sortedDates.first),
        'endTime': Timestamp.fromDate(sortedDates.last),
        'durationDays': selectedDates.length,
        'guidePrice': fee,
        'status': 'pending_acceptance', // ← set status
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnack('Task scheduled — awaiting builder acceptance');
      }
    } catch (e) {
      setState(() => isSaving = false);
      _showSnack('Failed to save. Please try again.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF6C63FF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.task.taskName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.task.description.isNotEmpty) ...[
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Task Description'),
                          const SizedBox(height: 8),
                          Text(widget.task.description,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Step 1: Select Builders ──────────────────────
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _stepBadge('1'),
                          const SizedBox(width: 8),
                          _sectionTitle('Select Builders'),
                        ]),
                        const SizedBox(height: 12),
                        if (selectedBuilderIds.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allContacts
                                .where((u) =>
                                    selectedBuilderIds.contains(u.uid))
                                .map((user) => Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor: user.avatarColor,
                                        backgroundImage:
                                            user.avatarUrl != null
                                                ? NetworkImage(user.avatarUrl!)
                                                : null,
                                        child: user.avatarUrl == null
                                            ? Text(user.initials,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10))
                                            : null,
                                      ),
                                      label: Text(user.name),
                                      deleteIcon:
                                          const Icon(Icons.close, size: 14),
                                      onDeleted: () {
                                        setState(() {
                                          selectedBuilderIds.remove(user.uid);
                                          occupiedRanges.remove(user.uid);
                                          selectedDates.clear();
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        GestureDetector(
                          onTap: () async {
                            final result =
                                await showModalBottomSheet<List<String>>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BuilderSelectionSheet(
                                allContacts: allContacts,
                                selectedIds: List.from(selectedBuilderIds),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                selectedBuilderIds = result;
                                selectedDates.clear();
                              });
                              if (result.isNotEmpty) {
                                final ranges =
                                    await _fetchOccupiedRanges(result);
                                setState(() => occupiedRanges = ranges);
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF6C63FF), width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_outlined,
                                    color: Color(0xFF6C63FF), size: 18),
                                SizedBox(width: 8),
                                Text('Select Builders',
                                    style: TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Step 2: Working Dates ────────────────────────
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _stepBadge('2'),
                          const SizedBox(width: 8),
                          _sectionTitle('Select Working Dates'),
                        ]),
                        if (selectedBuilderIds.isEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.grey[400], size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  'Select builders first to see availability',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text('Tap dates to select working days',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _legendItem(
                                  const Color(0xFF6C63FF), 'Selected'),
                              const SizedBox(width: 16),
                              _legendItem(
                                  Colors.grey.shade400, 'Occupied'),
                              const SizedBox(width: 16),
                              _legendItem(
                                  Colors.grey.shade200, 'Unavailable'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InlineCalendar(
                            selectedDates: selectedDates,
                            isOccupied: _isOccupied,
                            onDayTap: _toggleDate,
                          ),
                          if (selectedDates.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF)
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
                                      Text(
                                        '${selectedDates.length} working day${selectedDates.length > 1 ? 's' : ''} selected',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6C63FF),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => selectedDates.clear()),
                                        child: const Text('Clear all',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                  if (_startDate != null &&
                                      _endDate != null) ...[
                                    const SizedBox(height: 4),
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
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Step 3: Fee ──────────────────────────────────
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _stepBadge('3'),
                          const SizedBox(width: 8),
                          _sectionTitle('Fee'),
                        ]),
                        const SizedBox(height: 8),
                        if (widget.task.guidePriceMin > 0 ||
                            widget.task.guidePriceMax > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Guide price: \$${widget.task.guidePriceMin.toStringAsFixed(0)} – \$${widget.task.guidePriceMax.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ),
                        TextField(
                          controller: _feeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter agreed fee',
                            prefixIcon: const Icon(Icons.attach_money,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save & Send to Builder',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stepBadge(String number) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
          color: Color(0xFF6C63FF), shape: BoxShape.circle),
      child: Center(
        child: Text(number,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E)));
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

// ─────────────────────────────────────────────
// Inline Calendar
// ─────────────────────────────────────────────
class _InlineCalendar extends StatefulWidget {
  final Set<DateTime> selectedDates;
  final bool Function(DateTime) isOccupied;
  final void Function(DateTime) onDayTap;

  const _InlineCalendar({
    required this.selectedDates,
    required this.isOccupied,
    required this.onDayTap,
  });

  @override
  State<_InlineCalendar> createState() => _InlineCalendarState();
}

class _InlineCalendarState extends State<_InlineCalendar> {
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
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
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
              icon:
                  const Icon(Icons.chevron_left, color: Color(0xFF6C63FF)),
            ),
            Text(_monthLabel(_focusedMonth),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E))),
            IconButton(
              onPressed: () => setState(() => _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
              icon:
                  const Icon(Icons.chevron_right, color: Color(0xFF6C63FF)),
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
              bgColor = const Color(0xFF6C63FF);
              textColor = Colors.white;
            } else if (isOccupied) {
              bgColor = Colors.grey.shade300;
              textColor = Colors.grey.shade500;
            } else if (isPast) {
              textColor = Colors.grey.shade300;
            }

            return GestureDetector(
              onTap: isDisabled ? null : () => widget.onDayTap(normalized),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected && !isOccupied
                      ? Border.all(
                          color: const Color(0xFF6C63FF), width: 1.5)
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

// ─────────────────────────────────────────────
// Builder Selection Bottom Sheet
// ─────────────────────────────────────────────
class BuilderSelectionSheet extends StatefulWidget {
  final List<NetworkUser> allContacts;
  final List<String> selectedIds;

  const BuilderSelectionSheet({
    super.key,
    required this.allContacts,
    required this.selectedIds,
  });

  @override
  State<BuilderSelectionSheet> createState() => _BuilderSelectionSheetState();
}

class _BuilderSelectionSheetState extends State<BuilderSelectionSheet> {
  late List<String> _selectedIds;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allContacts.where((u) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.role?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Builders',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedIds),
                  child: const Text('Done',
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No contacts in your network.'
                          : 'No results for "$_query"',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final isSelected = _selectedIds.contains(user.uid);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedIds.remove(user.uid);
                          } else {
                            _selectedIds.add(user.uid);
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C63FF).withOpacity(0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6C63FF)
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: user.avatarColor,
                                backgroundImage: user.avatarUrl != null
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child: user.avatarUrl == null
                                    ? Text(user.initials,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(user.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Color(0xFF1A1A2E))),
                                    Text(user.subtitle,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? const Color(0xFF6C63FF)
                                    : Colors.grey[300],
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}