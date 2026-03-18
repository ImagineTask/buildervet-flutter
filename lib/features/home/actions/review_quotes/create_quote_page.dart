import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quote_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateQuotePage
//
// Fetches all tasks under the project.
// Contractor fills a price + optional notes per task.
// Live total updates as they type.
// On submit → writes one quote document to quotes/{quoteId} with a
// breakdown array containing every task's amount.
// ─────────────────────────────────────────────────────────────────────────────

class CreateQuotePage extends StatefulWidget {
  final String projectId;
  final String projectName;

  const CreateQuotePage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<CreateQuotePage> createState() => _CreateQuotePageState();
}

class _CreateQuotePageState extends State<CreateQuotePage> {
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _descControllers = {};
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _tasksLoading = true;
  double _total = 0;
  List<TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final snap = await FirebaseFirestore.instance
        .collection('tasks')
        .where('parentTaskId', isEqualTo: widget.projectId)
        .where('taskType', isEqualTo: 'task')
        .get();

    final tasks = snap.docs
        .map((d) => TaskItem.fromFirestore(d))
        .toList()
      ..sort((a, b) => a.taskOrder.compareTo(b.taskOrder));

    for (final task in tasks) {
      final ac = TextEditingController();
      ac.addListener(_recalcTotal);
      _amountControllers[task.taskId] = ac;
      _descControllers[task.taskId] = TextEditingController();
    }

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _tasksLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _amountControllers.values) c.dispose();
    for (final c in _descControllers.values) c.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    double sum = 0;
    for (final c in _amountControllers.values) {
      sum += double.tryParse(c.text.trim()) ?? 0;
    }
    setState(() => _total = sum);
  }

  Future<void> _submit(List<TaskItem> tasks) async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final builderName =
        (userDoc.data()?['name'] as String?) ?? 'Unknown Builder';

    setState(() => _loading = true);
    try {
      final breakdown = tasks
          .map((task) => BreakdownItem(
                taskId: task.taskId,
                taskName: task.taskName,
                amount: double.tryParse(
                        _amountControllers[task.taskId]!.text.trim()) ??
                    0,
                description: _descControllers[task.taskId]!.text.trim(),
              ).toMap())
          .toList();

      await FirebaseFirestore.instance.collection('quotes').add({
        'projectId': widget.projectId,
        'builderId': user.uid,
        'builderName': builderName,
        'totalAmount': _total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'breakdown': breakdown,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote submitted successfully'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit quote. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBody() {
    if (_tasksLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF43C59E)),
      );
    }
    if (_tasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks found for this project.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Live total bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Enter your price for each task',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF43C59E),
                      ),
                    ),
                    Text(
                      'Total',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _tasks.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: _SubmitButton(
                      total: _total,
                      loading: _loading,
                      onTap: () => _submit(_tasks),
                    ),
                  );
                }
                final task = _tasks[index];
                return _TaskInputCard(
                  task: task,
                  amountController: _amountControllers[task.taskId]!,
                  descController: _descControllers[task.taskId]!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text(
              'Create Quote',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Input Card
// ─────────────────────────────────────────────────────────────────────────────

class _TaskInputCard extends StatelessWidget {
  final TaskItem task;
  final TextEditingController amountController;
  final TextEditingController descController;

  const _TaskInputCard({
    required this.task,
    required this.amountController,
    required this.descController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.build_outlined,
                      size: 16, color: Color(0xFF43C59E)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.taskName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
                      if (task.guidePriceMin != null &&
                          task.guidePriceMax != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Guide: £${task.guidePriceMin!.toStringAsFixed(0)} – £${task.guidePriceMax!.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(
                  label: 'Your price (£)', icon: Icons.currency_pound),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a price for this task';
                }
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: descController,
              maxLines: 2,
              decoration: _inputDecoration(
                label: 'Notes (optional)',
                icon: Icons.notes_outlined,
                multiline: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit Button — shows live total inline
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final double total;
  final bool loading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.total,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: loading
              ? const Color(0xFF43C59E).withValues(alpha: 0.5)
              : const Color(0xFF43C59E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Submit Quote  •  £${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input decoration helper
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
  bool multiline = false,
}) {
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: multiline,
    prefixIcon: multiline
        ? Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Icon(icon, size: 16, color: const Color(0xFF43C59E)),
          )
        : Icon(icon, size: 16, color: const Color(0xFF43C59E)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
          const BorderSide(color: Color(0xFF43C59E), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}