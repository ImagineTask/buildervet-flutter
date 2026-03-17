import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteManagementPage
//
// Lists all tasks under a project, each showing its quote status + amount.
// Tap a task card → QuoteDetailPage for that task.
//
// Role-aware empty state:
//   contractor → "Create a Quote"
//   homeowner  → "Request a Quote"
// ─────────────────────────────────────────────────────────────────────────────

class QuoteManagementPage extends StatelessWidget {
  final String projectId;
  final String projectName;

  const QuoteManagementPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  // Fetch current user's role from users/{uid}
  Future<String> _fetchRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'homeowner';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return (doc.data()?['role'] as String?) ?? 'homeowner';
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
              projectName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text(
              'Quote Management',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: _fetchRole(),
        builder: (context, roleSnapshot) {
          final role = roleSnapshot.data ?? 'homeowner';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('projectId', isEqualTo: projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF43C59E)),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.grey)),
                );
              }

              final tasks = (snapshot.data?.docs ?? [])
                  .map((d) => _TaskWithQuote.fromFirestore(d))
                  .toList();

              // Tasks exist but none have quotes yet
              final quotedTasks =
                  tasks.where((t) => t.quote != null).toList();

              if (tasks.isEmpty || quotedTasks.isEmpty) {
                return _EmptyState(role: role, projectId: projectId);
              }

              // Summary counts
              final pending = quotedTasks
                  .where((t) => t.quote?.status == 'pending')
                  .length;
              final accepted = quotedTasks
                  .where((t) => t.quote?.status == 'accepted')
                  .length;
              final totalQuoted = quotedTasks.fold<double>(
                  0, (acc, t) => acc + (t.quote?.amount ?? 0));

              return Column(
                children: [
                  // ── Summary bar ────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _Chip(
                          label:
                              '${quotedTasks.length} / ${tasks.length} Quoted',
                          color: const Color(0xFF43C59E),
                        ),
                        if (pending > 0) ...[
                          const SizedBox(width: 8),
                          _Chip(
                            label: '$pending Pending',
                            color: const Color(0xFFFFB347),
                            dot: true,
                          ),
                        ],
                        if (accepted > 0) ...[
                          const SizedBox(width: 8),
                          _Chip(
                            label: '$accepted Approved',
                            color: const Color(0xFF43C59E),
                          ),
                        ],
                        const Spacer(),
                        if (totalQuoted > 0)
                          Text(
                            '£${totalQuoted.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Task list ──────────────────────────────────────────
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: quotedTasks.length,
                      itemBuilder: (context, index) => _TaskQuoteCard(
                        task: quotedTasks[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuoteDetailPage(
                              task: quotedTasks[index],
                              role: role,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QuoteDetailPage
//
// Full quote detail for a single task.
// Role-aware — contractors see SendQuoteWidget, homeowners see approve/decline.
// ─────────────────────────────────────────────────────────────────────────────

class QuoteDetailPage extends StatelessWidget {
  final _TaskWithQuote task;
  final String role;

  const QuoteDetailPage({
    super.key,
    required this.task,
    required this.role,
  });

  bool get _isContractor => role == 'contractor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          task.taskName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Task metadata (guide price + contractor type)
          _TaskInfoCard(task: task),
          const SizedBox(height: 16),

          // Existing quote details
          if (task.quote != null) ...[
            _QuoteInfoCard(task: task),
            const SizedBox(height: 16),

            // Homeowner sees approve/decline on pending quotes
            if (!_isContractor && task.quote!.status == 'pending') ...[
              _ApproveButton(task: task),
              const SizedBox(height: 10),
              _DeclineButton(task: task),
              const SizedBox(height: 16),
            ],
          ],

          // Contractor sees send quote form
          if (_isContractor) ...[
            SendQuoteWidget(taskId: task.taskId),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteData {
  final String builderId;
  final String builderName;
  final double amount;
  final String description;
  final String status;
  final DateTime submittedAt;

  const _QuoteData({
    required this.builderId,
    required this.builderName,
    required this.amount,
    required this.description,
    required this.status,
    required this.submittedAt,
  });

  factory _QuoteData.fromMap(Map<String, dynamic> m) => _QuoteData(
        builderId: m['builderId'] ?? '',
        builderName: m['builderName'] ?? 'Unknown Builder',
        amount: (m['amount'] ?? 0).toDouble(),
        description: m['description'] ?? '',
        status: m['status'] ?? 'pending',
        submittedAt: _parseDate(m['submittedAt']),
      );

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

class _TaskWithQuote {
  final String taskId;
  final String taskName;
  final String contractorType;
  final double? guidePriceMin;
  final double? guidePriceMax;
  final String status;
  final _QuoteData? quote;

  const _TaskWithQuote({
    required this.taskId,
    required this.taskName,
    required this.contractorType,
    required this.guidePriceMin,
    required this.guidePriceMax,
    required this.status,
    required this.quote,
  });

  factory _TaskWithQuote.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final meta = d['metadata'] as Map<String, dynamic>? ?? {};
    final quoteMap = d['quote'] as Map<String, dynamic>?;

    return _TaskWithQuote(
      taskId: doc.id,
      taskName: d['taskName'] ?? 'Unnamed Task',
      contractorType: meta['contractorType'] ?? d['contractorType'] ?? '',
      guidePriceMin:
          (meta['guidePriceMin'] ?? d['guidePriceMin'])?.toDouble(),
      guidePriceMax:
          (meta['guidePriceMax'] ?? d['guidePriceMax'])?.toDouble(),
      status: d['status'] ?? 'draft',
      quote: quoteMap != null ? _QuoteData.fromMap(quoteMap) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Quote Card — shown in the list on QuoteManagementPage
// ─────────────────────────────────────────────────────────────────────────────

class _TaskQuoteCard extends StatelessWidget {
  final _TaskWithQuote task;
  final VoidCallback onTap;

  const _TaskQuoteCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final q = task.quote;
    final isPending = q?.status == 'pending';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isPending
              ? Border.all(color: const Color(0xFFFFB347), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_outlined,
                    size: 20, color: Color(0xFF43C59E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.taskName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (task.contractorType.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.contractorType,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                    if (q != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        q.builderName,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (q != null) ...[
                    Row(
                      children: [
                        Icon(Icons.currency_pound,
                            size: 12, color: Colors.grey[400]),
                        Text(
                          q.amount.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(status: q.status),
                  ] else ...[
                    Text(
                      'No quote',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[400]),
                    ),
                    if (task.guidePriceMin != null &&
                        task.guidePriceMax != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '£${task.guidePriceMin!.toStringAsFixed(0)}–£${task.guidePriceMax!.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: Colors.grey[300], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _TaskInfoCard extends StatelessWidget {
  final _TaskWithQuote task;
  const _TaskInfoCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF43C59E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF43C59E).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Color(0xFF43C59E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.contractorType.isNotEmpty)
                  Text(
                    task.contractorType,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                if (task.guidePriceMin != null &&
                    task.guidePriceMax != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Guide price: £${task.guidePriceMin!.toStringAsFixed(0)} – £${task.guidePriceMax!.toStringAsFixed(0)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
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

// ─────────────────────────────────────────────────────────────────────────────
// Quote Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteInfoCard extends StatelessWidget {
  final _TaskWithQuote task;
  const _QuoteInfoCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final q = task.quote!;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF43C59E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    size: 20, color: Color(0xFF43C59E)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  q.builderName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              _StatusBadge(status: q.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.currency_pound,
                  size: 13, color: Colors.grey[400]),
              Text(
                q.amount.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          if (q.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_outlined,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '${q.submittedAt.day}/${q.submittedAt.month}/${q.submittedAt.year}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approve Button
// ─────────────────────────────────────────────────────────────────────────────

class _ApproveButton extends StatefulWidget {
  final _TaskWithQuote task;
  const _ApproveButton({required this.task});

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.taskId)
          .update({
        'quote.status': 'accepted',
        'quote.resolvedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote approved'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PrimaryButton(
        label: 'Approve Quote',
        icon: Icons.check_rounded,
        color: const Color(0xFF43C59E),
        loading: _loading,
        onTap: _approve,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Decline Button
// ─────────────────────────────────────────────────────────────────────────────

class _DeclineButton extends StatefulWidget {
  final _TaskWithQuote task;
  const _DeclineButton({required this.task});

  @override
  State<_DeclineButton> createState() => _DeclineButtonState();
}

class _DeclineButtonState extends State<_DeclineButton> {
  bool _loading = false;

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Quote',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        content: Text(
          'Decline the quote from ${widget.task.quote!.builderName}?',
          style: const TextStyle(color: Colors.grey),
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

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.taskId)
          .update({
        'quote.status': 'declined',
        'quote.resolvedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PrimaryButton(
        label: 'Decline Quote',
        icon: Icons.close_rounded,
        color: const Color(0xFFFF6B6B),
        loading: _loading,
        onTap: _decline,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SendQuoteWidget
// Contractor submits a quote by writing to tasks/{taskId}.quote
// ─────────────────────────────────────────────────────────────────────────────

class SendQuoteWidget extends StatefulWidget {
  final String taskId;
  final VoidCallback? onSent;

  const SendQuoteWidget({
    super.key,
    required this.taskId,
    this.onSent,
  });

  @override
  State<SendQuoteWidget> createState() => _SendQuoteWidgetState();
}

class _SendQuoteWidgetState extends State<SendQuoteWidget> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch builder name from users/{uid}
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final builderName =
        (userDoc.data()?['name'] as String?) ?? 'Unknown Builder';

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
        'quote': {
          'builderId': user.uid,
          'builderName': builderName,
          'amount': double.parse(_amountController.text.trim()),
          'description': _descController.text.trim(),
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
        },
      });
      if (mounted) {
        _amountController.clear();
        _descController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote sent successfully'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
        widget.onSent?.call();
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

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Send a Quote',
      icon: Icons.send_rounded,
      iconColor: const Color(0xFF43C59E),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration(
                  label: 'Amount (£)', icon: Icons.currency_pound),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter an amount';
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: _fieldDecoration(
                  label: 'Description (optional)',
                  icon: Icons.notes_outlined,
                  multiline: true),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: 'Send Quote',
              icon: Icons.send_rounded,
              color: const Color(0xFF43C59E),
              loading: _loading,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State — role aware
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String role;
  final String projectId;

  const _EmptyState({required this.role, required this.projectId});

  bool get _isContractor => role == 'contractor';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.request_quote_outlined,
                  size: 36, color: Color(0xFF43C59E)),
            ),
            const SizedBox(height: 20),
            Text(
              _isContractor ? 'No quotes yet' : 'No quotes received yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isContractor
                  ? 'Submit a quote for a task to get started.'
                  : 'Builders will submit quotes for your tasks here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _TaskPickerPage(
                    projectId: projectId,
                    role: role,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF43C59E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isContractor
                          ? Icons.add_circle_outline
                          : Icons.send_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isContractor
                          ? 'Create a Quote'
                          : 'Request a Quote',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Picker Page
// Lists all tasks under the project so the user can pick one to quote.
// ─────────────────────────────────────────────────────────────────────────────

class _TaskPickerPage extends StatelessWidget {
  final String projectId;
  final String role;

  const _TaskPickerPage({
    required this.projectId,
    required this.role,
  });

  bool get _isContractor => role == 'contractor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          _isContractor ? 'Select Task to Quote' : 'Request a Quote',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('projectId', isEqualTo: projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF43C59E)),
            );
          }

          final tasks = (snapshot.data?.docs ?? [])
              .map((d) => _TaskWithQuote.fromFirestore(d))
              .toList();

          if (tasks.isEmpty) {
            return Center(
              child: Text(
                'No tasks found for this project.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final hasQuote = task.quote != null;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuoteDetailPage(
                      task: task,
                      role: role,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF43C59E)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.build_outlined,
                            size: 20, color: Color(0xFF43C59E)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.taskName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            if (task.contractorType.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                task.contractorType,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasQuote)
                        _StatusBadge(status: task.quote!.status)
                      else
                        Icon(Icons.chevron_right,
                            color: Colors.grey[300], size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;
  const _Chip(
      {required this.label, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: loading ? color.withValues(alpha: 0.5) : color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  bool multiline = false,
}) {
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: multiline,
    prefixIcon: multiline
        ? Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Icon(icon, size: 18, color: const Color(0xFF43C59E)),
          )
        : Icon(icon, size: 18, color: const Color(0xFF43C59E)),
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
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}