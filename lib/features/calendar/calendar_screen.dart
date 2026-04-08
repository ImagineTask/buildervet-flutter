import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
// Task model (lightweight, calendar-only)
// ─────────────────────────────────────────────
class _CalendarTask {
  final String taskId;
  final String taskName;
  final String status;
  final String contractorType;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationDays;
  final List<String> assignedBuilderIds;
  final List<String> builderNames; // resolved from users collection

  _CalendarTask({
    required this.taskId,
    required this.taskName,
    required this.status,
    required this.contractorType,
    this.startTime,
    this.endTime,
    required this.durationDays,
    this.assignedBuilderIds = const [],
    this.builderNames = const [],
  });

  factory _CalendarTask.fromMap(Map<String, dynamic> d) {
    return _CalendarTask(
      taskId: d['taskId'] as String? ?? '',
      taskName: d['taskName'] as String? ?? 'Untitled Task',
      status: d['status'] as String? ?? 'unassigned',
      contractorType: d['contractorType'] as String? ?? '',
      startTime: _parseDate(d['startTime']),
      endTime: _parseDate(d['endTime']),
      durationDays: (d['durationDays'] as int?) ?? 1,
      assignedBuilderIds: List<String>.from(d['assignedBuilderIds'] ?? []),
    );
  }

  _CalendarTask withBuilderNames(List<String> names) => _CalendarTask(
        taskId: taskId,
        taskName: taskName,
        status: status,
        contractorType: contractorType,
        startTime: startTime,
        endTime: endTime,
        durationDays: durationDays,
        assignedBuilderIds: assignedBuilderIds,
        builderNames: names,
      );

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Task is "active" on a given day if the day falls between startTime and endTime
  bool isActiveOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (startTime == null) return false;
    final start = DateTime(startTime!.year, startTime!.month, startTime!.day);
    final end = endTime != null
        ? DateTime(endTime!.year, endTime!.month, endTime!.day)
        : start.add(Duration(days: durationDays - 1));
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

// ─────────────────────────────────────────────
// Status helpers
// ─────────────────────────────────────────────
extension _StatusStyle on String {
  Color get statusColor {
    switch (this) {
      case 'active':
        return const Color(0xFF43C59E);
      case 'completed':
        return const Color(0xFF6C63FF);
      case 'unassigned':
        return const Color(0xFFFFB347);
      case 'pending':
        return const Color(0xFF4F6EF7);
      case 'revising':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF9899A6);
    }
  }

  String get statusLabel {
    switch (this) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'unassigned':
        return 'Unassigned';
      case 'pending':
        return 'Pending';
      case 'revising':
        return 'Revising';
      default:
        return 'Unknown';
    }
  }
}

// ─────────────────────────────────────────────
// CalendarScreen
// ─────────────────────────────────────────────
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // ── Calendar navigation ───────────────────────────────────────────
  late int _viewMonth;
  late int _viewYear;
  late DateTime _selectedDate;

  // ── Task data ─────────────────────────────────────────────────────
  List<_CalendarTask> _allTasks = [];
  bool _loadingTasks = true;

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _monthShort = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = now.month;
    _viewYear = now.year;
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadTasks();
  }

  // ── Load tasks from Firestore ─────────────────────────────────────
  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Load tasks where the user is a participant or owner
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('taskType', isEqualTo: 'task')
          .where('participantIds', arrayContains: uid)
          .get();

      // Parse tasks
      final tasks = snap.docs
          .map((d) => _CalendarTask.fromMap(d.data()))
          .where((t) => t.startTime != null)
          .toList();

      // Collect all unique builder UIDs across all tasks
      final allBuilderIds = tasks
          .expand((t) => t.assignedBuilderIds)
          .toSet()
          .toList();

      // Batch-fetch user names (Firestore allows max 30 per whereIn)
      final Map<String, String> uidToName = {};
      for (int i = 0; i < allBuilderIds.length; i += 30) {
        final batch = allBuilderIds.sublist(
            i, i + 30 > allBuilderIds.length ? allBuilderIds.length : i + 30);
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in userSnap.docs) {
          final data = doc.data();
          final name = data['name'] as String? ??
              data['displayName'] as String? ??
              data['email'] as String? ??
              'Builder';
          uidToName[doc.id] = name;
        }
      }

      // Attach resolved names to each task
      final resolvedTasks = tasks.map((t) {
        final names = t.assignedBuilderIds
            .map((id) => uidToName[id] ?? 'Builder')
            .toList();
        return t.withBuilderNames(names);
      }).toList();

      setState(() {
        _allTasks = resolvedTasks;
        _loadingTasks = false;
      });
    } catch (e) {
      debugPrint('Calendar task load error: $e');
      setState(() => _loadingTasks = false);
    }
  }

  // ── Days that have at least one task this month ───────────────────
  Set<int> _daysWithTasks() {
    final result = <int>{};
    for (final task in _allTasks) {
      final daysInMonth = DateUtils.getDaysInMonth(_viewYear, _viewMonth);
      for (int day = 1; day <= daysInMonth; day++) {
        if (task.isActiveOn(DateTime(_viewYear, _viewMonth, day))) {
          result.add(day);
        }
      }
    }
    return result;
  }

  // ── Tasks for selected date ───────────────────────────────────────
  List<_CalendarTask> get _selectedTasks =>
      _allTasks.where((t) => t.isActiveOn(_selectedDate)).toList();

  // ── Month navigation ──────────────────────────────────────────────
  void _prevMonth() {
    setState(() {
      if (_viewMonth == 1) {
        _viewMonth = 12;
        _viewYear--;
      } else {
        _viewMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == 12) {
        _viewMonth = 1;
        _viewYear++;
      } else {
        _viewMonth++;
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == _viewYear && now.month == _viewMonth && now.day == day;
  }

  bool _isSelected(int day) =>
      _selectedDate.year == _viewYear &&
      _selectedDate.month == _viewMonth &&
      _selectedDate.day == day;

  String _formatSelectedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (_selectedDate == today) return 'Today';
    if (_selectedDate == tomorrow) return 'Tomorrow';
    return '${_selectedDate.day} ${_monthShort[_selectedDate.month]}';
  }

  String _formatTaskTime(_CalendarTask task) {
    if (task.startTime == null) return '';
    final s = task.startTime!;
    final e = task.endTime;
    final start =
        '${_monthShort[s.month]} ${s.day}';
    if (e == null) return start;
    final end = '${_monthShort[e.month]} ${e.day}';
    return '$start – $end  ·  ${task.durationDays}d';
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calendar',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        '${_monthNames[_viewMonth]} $_viewYear',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Refresh
                      IconButton(
                        onPressed: _loadTasks,
                        icon: _loadingTasks
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF6C63FF), strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: Color(0xFF6C63FF)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Calendar card ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Month navigation row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: Color(0xFF1A1A2E)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          '${_monthNames[_viewMonth]} $_viewYear',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        IconButton(
                          onPressed: _nextMonth,
                          icon: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF1A1A2E)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Weekday labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _weekDays
                          .map((d) => SizedBox(
                                width: 36,
                                child: Center(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),

                    // Days grid
                    _buildDaysGrid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Task list for selected date ───────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatSelectedDate(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedTasks.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_selectedTasks.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _loadingTasks
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF6C63FF), strokeWidth: 2),
                            )
                          : _selectedTasks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_available_outlined,
                                          size: 40,
                                          color: Colors.grey[300]),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No tasks on this day',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _selectedTasks.length,
                                  itemBuilder: (context, index) =>
                                      _TaskCard(
                                        task: _selectedTasks[index],
                                        timeLabel: _formatTaskTime(
                                            _selectedTasks[index]),
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

  // ── Days grid builder ─────────────────────────────────────────────

  Widget _buildDaysGrid() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_viewYear, _viewMonth);
    // weekday: 1=Mon ... 7=Sun → offset for Mon-first grid
    final firstWeekday =
        DateTime(_viewYear, _viewMonth, 1).weekday; // 1-7
    final startOffset = firstWeekday - 1; // 0-6
    final daysWithTasks = _daysWithTasks();

    final List<Widget> cells = [];

    // Leading empty cells
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox(width: 36, height: 36));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final selected = _isSelected(day);
      final today = _isToday(day);
      final hasTask = daysWithTasks.contains(day);

      cells.add(
        GestureDetector(
          onTap: () => setState(
              () => _selectedDate = DateTime(_viewYear, _viewMonth, day)),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection / today ring
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6C63FF)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: today && !selected
                        ? Border.all(
                            color: const Color(0xFF6C63FF), width: 1.5)
                        : null,
                  ),
                ),
                // Day number
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected || today
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: selected
                            ? Colors.white
                            : today
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF1A1A2E),
                      ),
                    ),
                    // Task dot
                    if (hasTask)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 5),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Build rows of 7
    final List<Widget> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7) > cells.length ? cells.length : i + 7;
      final rowCells = cells.sublist(i, end);
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox(width: 36, height: 36));
      }
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: rowCells,
      ));
      if (i + 7 < cells.length) rows.add(const SizedBox(height: 2));
    }

    return Column(children: rows);
  }
}

// ─────────────────────────────────────────────
// Task Card
// ─────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final _CalendarTask task;
  final String timeLabel;

  const _TaskCard({required this.task, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    final statusColor = task.status.statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Colour bar
          Container(
            width: 4,
            height: 46,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.construction_outlined,
                color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (task.contractorType.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.contractorType,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
                if (task.builderNames.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          task.builderNames.first,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else if (task.status == 'unassigned') ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.person_add_outlined,
                          size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        'No builder assigned',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        timeLabel,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),


        ],
      ),
    );
  }
}