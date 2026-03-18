import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BreakdownItem — one task line inside a quote
// ─────────────────────────────────────────────────────────────────────────────

class BreakdownItem {
  final String taskId;
  final String taskName;
  final double amount;
  final String description;

  const BreakdownItem({
    required this.taskId,
    required this.taskName,
    required this.amount,
    required this.description,
  });

  factory BreakdownItem.fromMap(Map<String, dynamic> m) => BreakdownItem(
        taskId: m['taskId'] ?? '',
        taskName: m['taskName'] ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
        description: m['description'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'taskName': taskName,
        'amount': amount,
        'description': description,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// QuoteModel — one quote per builder per project
// quotes/{quoteId}
// ─────────────────────────────────────────────────────────────────────────────

class QuoteModel {
  final String id;
  final String projectId;
  final String builderId;
  final String builderName;
  final double totalAmount;
  final String status; // pending | accepted | declined
  final DateTime createdAt;
  final List<BreakdownItem> breakdown;

  const QuoteModel({
    required this.id,
    required this.projectId,
    required this.builderId,
    required this.builderName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.breakdown,
  });

  factory QuoteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final raw = d['breakdown'] as List<dynamic>? ?? [];
    return QuoteModel(
      id: doc.id,
      projectId: d['projectId'] ?? '',
      builderId: d['builderId'] ?? '',
      builderName: d['builderName'] ?? 'Unknown Builder',
      totalAmount: (d['totalAmount'] ?? 0).toDouble(),
      status: d['status'] ?? 'pending',
      createdAt: _parseDate(d['createdAt']),
      breakdown: raw
          .map((e) => BreakdownItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaskItem — a task document under a project (used in CreateQuotePage)
// ─────────────────────────────────────────────────────────────────────────────

class TaskItem {
  final String taskId;
  final String taskName;
  final String contractorType;
  final double? guidePriceMin;
  final double? guidePriceMax;
  final int taskOrder;

  const TaskItem({
    required this.taskId,
    required this.taskName,
    required this.contractorType,
    required this.guidePriceMin,
    required this.guidePriceMax,
    required this.taskOrder,
  });

  factory TaskItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final meta = d['metadata'] as Map<String, dynamic>? ?? {};
    return TaskItem(
      taskId: doc.id,
      taskName: d['taskName'] ?? 'Unnamed Task',
      contractorType: d['contractorType'] ?? '',
      guidePriceMin: (d['guidePriceMin'])?.toDouble(),
      guidePriceMax: (d['guidePriceMax'])?.toDouble(),
      taskOrder: (meta['taskOrder'] as int?) ?? 0,
    );
  }
}
