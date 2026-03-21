import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quote_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateQuotePage
//
// Builder fills in material + labour per task.
// On Send → batch writes quote fields to all tasks/{taskId} documents.
// First quote  → labour defaults to guidePrice, material to 0
// Update quote → pre-fills from existing quoteMaterial / quoteLabour
// ─────────────────────────────────────────────────────────────────────────────

class CreateQuotePage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<TaskItem>? existingTasks; // non-null when updating

  const CreateQuotePage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.existingTasks,
  });

  @override
  State<CreateQuotePage> createState() => _CreateQuotePageState();
}

class _CreateQuotePageState extends State<CreateQuotePage> {
  final Map<String, TextEditingController> _materialControllers = {};
  final Map<String, TextEditingController> _labourControllers = {};
  final _reasonController = TextEditingController();
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
      // Pre-fill from existing quote or default to guidePrice/0
      final existingMaterial =
          task.quoteMaterial?.toStringAsFixed(0) ?? '0';
      final existingLabour = task.quoteLabour?.toStringAsFixed(0) ??
          (task.guidePrice != null && task.guidePrice! > 0
              ? task.guidePrice!.toStringAsFixed(0)
              : '0');

      final mc = TextEditingController(text: existingMaterial);
      final lc = TextEditingController(text: existingLabour);
      mc.addListener(_recalcTotal);
      lc.addListener(_recalcTotal);
      _materialControllers[task.taskId] = mc;
      _labourControllers[task.taskId] = lc;
    }

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _tasksLoading = false;
      });
      _recalcTotal();
    }
  }

  @override
  void dispose() {
    for (final c in _materialControllers.values) c.dispose();
    for (final c in _labourControllers.values) c.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    double sum = 0;
    for (final c in _materialControllers.values) {
      sum += double.tryParse(c.text.trim()) ?? 0;
    }
    for (final c in _labourControllers.values) {
      sum += double.tryParse(c.text.trim()) ?? 0;
    }
    setState(() => _total = sum);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Show note dialog when updating an existing quote
    if (widget.existingTasks != null) {
      _reasonController.clear();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Update Quote',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a note for the homeowner explaining the changes (optional).',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Material costs have increased...',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF43C59E), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
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
                backgroundColor: const Color(0xFF43C59E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

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
      final batch = FirebaseFirestore.instance.batch();
      for (final task in _tasks) {
        final material = double.tryParse(
                _materialControllers[task.taskId]!.text.trim()) ??
            0;
        final labour = double.tryParse(
                _labourControllers[task.taskId]!.text.trim()) ??
            0;
        final ref = FirebaseFirestore.instance
            .collection('tasks')
            .doc(task.taskId);
        final reason = widget.existingTasks != null
            ? _reasonController.text.trim()
            : null;

        final historyEntry = {
          'type': 'submitted',
          'material': material,
          'labour': labour,
          'total': material + labour,
          'submittedAt': DateTime.now().toIso8601String(),
          'actorName': builderName,
          if (reason != null && reason.isNotEmpty) 'note': reason,
        };

        final fields = <String, dynamic>{
          'quoteBuilderId': user.uid,
          'quoteBuilderName': builderName,
          'quoteMaterial': material,
          'quoteLabour': labour,
          'quoteTotal': material + labour,
          'quoteStatus': 'pending',
          'quoteSubmittedAt': FieldValue.serverTimestamp(),
          'quoteHistory': FieldValue.arrayUnion([historyEntry]),
        };
        if (reason != null) {
          fields['quoteUpdateReason'] = reason.isEmpty ? null : reason;
        }
        batch.update(ref, fields);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote sent successfully'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send quote. Try again.'),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Enter material & labour per task',
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
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400]),
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
                    child: _SendButton(
                      total: _total,
                      loading: _loading,
                      onTap: _submit,
                    ),
                  );
                }
                final task = _tasks[index];
                return _TaskInputCard(
                  task: task,
                  materialController:
                      _materialControllers[task.taskId]!,
                  labourController: _labourControllers[task.taskId]!,
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
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
  final TextEditingController materialController;
  final TextEditingController labourController;

  const _TaskInputCard({
    required this.task,
    required this.materialController,
    required this.labourController,
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
                    color:
                        const Color(0xFF43C59E).withValues(alpha: 0.1),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: materialController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDecoration(
                        label: 'Material (£)',
                        icon: Icons.hardware_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: labourController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDecoration(
                        label: 'Labour (£)',
                        icon: Icons.handyman_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Send Button
// ─────────────────────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  final double total;
  final bool loading;
  final VoidCallback onTap;

  const _SendButton({
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
                      'Send  •  £${total.toStringAsFixed(0)}',
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

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 16, color: const Color(0xFF43C59E)),
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