import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../models/participant.dart';
import '../../../providers/task_provider.dart';
import '../../../shared/widgets/badges/status_badge.dart';
import '../../../shared/widgets/feedback/feedback_widgets.dart';

class TaskScheduleScreen extends ConsumerWidget {
  final String taskId;

  const TaskScheduleScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
      ),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const ErrorView(message: 'Task not found');
          }
          return _ScheduleContent(task: task);
        },
        loading: () => const LoadingIndicator(),
        error: (err, _) => ErrorView(message: err.toString()),
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  final Task task;

  const _ScheduleContent({required this.task});

  @override
  Widget build(BuildContext context) {
    final days = task.durationDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge(status: task.status),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Timeline
          Text('Timeline', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),

          _DateCard(
            icon: Icons.flag_outlined,
            label: 'Start Date',
            date: task.startTime,
            color: const Color(0xFF00B894),
            onEdit: () {},
          ),
          const SizedBox(height: AppSpacing.sm),

          // Duration indicator
          Container(
            margin: const EdgeInsets.only(left: 24),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 2)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  days != null ? '$days days duration' : 'Duration not set',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          _DateCard(
            icon: Icons.flag,
            label: 'End Date',
            date: task.endTime,
            color: const Color(0xFFFF6B6B),
            onEdit: () {},
          ),
          const SizedBox(height: AppSpacing.lg),

          // Progress
          if (days != null) ...[
            Text('Progress', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            _ProgressCard(task: task, totalDays: days),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Assigned People with Add
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assigned People (${task.participants.length})',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAssignPersonSheet(context),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assign'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (task.participants.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 36, color: AppColors.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('No one assigned yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Tap Assign to add someone and set their schedule', style: TextStyle(fontSize: 12, color: AppColors.textTertiary), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...task.participants.map((p) => _AssignedPersonCard(
              participant: p,
              taskStartTime: task.startTime,
              taskEndTime: task.endTime,
              onRemove: () {},
              onEditDates: () {},
            )),

          const SizedBox(height: AppSpacing.lg),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Add to Calendar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignPersonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignPersonSheet(
        taskStartTime: task.startTime,
        taskEndTime: task.endTime,
      ),
    );
  }
}

// ─── Assigned Person Card ────────────────────────────────

class _AssignedPersonCard extends StatelessWidget {
  final Participant participant;
  final DateTime taskStartTime;
  final DateTime taskEndTime;
  final VoidCallback onRemove;
  final VoidCallback onEditDates;

  const _AssignedPersonCard({
    required this.participant,
    required this.taskStartTime,
    required this.taskEndTime,
    required this.onRemove,
    required this.onEditDates,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(participant.role.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(participant.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(participant.role.label, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              IconButton(icon: Icon(Icons.edit, size: 18, color: AppColors.textSecondary), onPressed: onEditDates, tooltip: 'Edit dates'),
              IconButton(icon: Icon(Icons.close, size: 18, color: AppColors.error.withOpacity(0.7)), onPressed: onRemove, tooltip: 'Remove'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  DateUtils2.dateRange(taskStartTime, taskEndTime),
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${taskEndTime.difference(taskStartTime).inDays} days',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assign Person Sheet ─────────────────────────────────

class _AssignPersonSheet extends StatefulWidget {
  final DateTime taskStartTime;
  final DateTime taskEndTime;

  const _AssignPersonSheet({required this.taskStartTime, required this.taskEndTime});

  @override
  State<_AssignPersonSheet> createState() => _AssignPersonSheetState();
}

class _AssignPersonSheetState extends State<_AssignPersonSheet> {
  _NetworkContact? _selectedContact;
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _allContacts = [
    _NetworkContact(name: 'Bob Martinez', role: 'Contractor', company: 'Martinez Building Co.', icon: Icons.construction, color: Color(0xFFFF6B6B)),
    _NetworkContact(name: 'Claire Wright', role: 'Designer', company: 'Wright Interiors', icon: Icons.brush, color: Color(0xFF45B7D1)),
    _NetworkContact(name: 'Dave Kowalski', role: 'Electrician', company: 'SparkRight Electrical', icon: Icons.electrical_services, color: Color(0xFFFECA57)),
    _NetworkContact(name: 'Emma Patel', role: 'Plumber', company: 'AquaFix Plumbing', icon: Icons.plumbing, color: Color(0xFF00B894)),
    _NetworkContact(name: 'Frank Green', role: 'Gas Engineer', company: 'SafeGas Services', icon: Icons.local_fire_department, color: Color(0xFFE17055)),
    _NetworkContact(name: 'Grace Kim', role: 'Painter', company: 'Fresh Coat Decorators', icon: Icons.format_paint, color: Color(0xFF6C5CE7)),
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.taskStartTime;
    _endDate = widget.taskEndTime;
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_NetworkContact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _allContacts;
    return _allContacts.where((c) {
      return c.name.toLowerCase().contains(_searchQuery) ||
          c.role.toLowerCase().contains(_searchQuery) ||
          c.company.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate! : _endDate!,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _confirm() {
    if (_selectedContact == null || _startDate == null || _endDate == null) return;

    // TODO: Add participant to task via provider with dates
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedContact!.name} assigned (${DateUtils2.dateRange(_startDate!, _endDate!)})'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    final canConfirm = _selectedContact != null && _startDate != null && _endDate != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Assign Person', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Select someone and set their working dates', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),

              // Step 1
              Text('1. Select Person', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, role, or company...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected = _selectedContact?.name == contact.name;

                    return InkWell(
                      onTap: () => setState(() => _selectedContact = contact),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected ? contact.color.withOpacity(0.08) : null,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: isSelected ? Border.all(color: contact.color.withOpacity(0.3)) : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: contact.color.withOpacity(0.15),
                              child: Icon(contact.icon, color: contact.color, size: 18),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(contact.name, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                                  Text('${contact.role} — ${contact.company}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, size: 22, color: contact.color)
                            else
                              Icon(Icons.circle_outlined, size: 22, color: AppColors.textTertiary.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Step 2
              Text('2. Set Working Dates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context, true),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 16, color: const Color(0xFF00B894)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_startDate != null ? DateUtils2.formatDateTime(_startDate!) : 'Select', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context, false),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.flag, size: 16, color: const Color(0xFFFF6B6B)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_endDate != null ? DateUtils2.formatDateTime(_endDate!) : 'Select', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_startDate != null && _endDate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    '${_endDate!.difference(_startDate!).inDays} days',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canConfirm ? _confirm : null,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(
                    _selectedContact != null ? 'Assign ${_selectedContact!.name}' : 'Select a person to assign',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkContact {
  final String name;
  final String role;
  final String company;
  final IconData icon;
  final Color color;
  const _NetworkContact({required this.name, required this.role, required this.company, required this.icon, required this.color});
}

// ─── Date Card ───────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime date;
  final Color color;
  final VoidCallback onEdit;

  const _DateCard({required this.icon, required this.label, required this.date, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                Text(DateUtils2.formatDateTime(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: Icon(Icons.edit, size: 18, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Progress Card ───────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final Task task;
  final int totalDays;

  const _ProgressCard({required this.task, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final elapsed = now.difference(task.startTime).inDays;
    final progress = totalDays > 0 ? (elapsed / totalDays).clamp(0.0, 1.0) : 0.0;
    final remaining = totalDays - elapsed;

    Color progressColor;
    String statusText;

    if (now.isBefore(task.startTime)) {
      progressColor = AppColors.textTertiary;
      statusText = 'Not started — begins ${DateUtils2.timeAgo(task.startTime)}';
    } else if (now.isAfter(task.endTime)) {
      progressColor = const Color(0xFFD63031);
      statusText = 'Overdue by ${now.difference(task.endTime).inDays} days';
    } else {
      progressColor = const Color(0xFF00B894);
      statusText = '$remaining days remaining';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${(progress * 100).round()}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: progressColor)),
              const Spacer(),
              Text(statusText, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, backgroundColor: AppColors.surfaceLight, valueColor: AlwaysStoppedAnimation(progressColor), minHeight: 8),
          ),
        ],
      ),
    );
  }
}