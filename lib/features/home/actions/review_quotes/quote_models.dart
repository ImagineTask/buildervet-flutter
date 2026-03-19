import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProjectQuote
//
// Represents the overall quote for a project, derived from all task documents.
// Each task stores its own quote fields (quoteMaterial, quoteLabour, etc.).
// The overall status is stored consistently across all tasks.
// ─────────────────────────────────────────────────────────────────────────────

class ProjectQuote {
  final String builderId;
  final String builderName;
  final double totalMaterial;
  final double totalLabour;
  final String status; // pending | accepted | declined
  final DateTime submittedAt;

  final double agreedMaterial;
  final double agreedLabour;
  final String? homeownerId;
  final String? declineReason;

  double get total => totalMaterial + totalLabour;
  double get agreedTotal => agreedMaterial + agreedLabour;

  const ProjectQuote({
    required this.builderId,
    required this.builderName,
    required this.totalMaterial,
    required this.totalLabour,
    required this.agreedMaterial,
    required this.agreedLabour,
    required this.status,
    required this.submittedAt,
    this.homeownerId,
    this.declineReason,
  });

  /// Derives one ProjectQuote from all task documents.
  /// Returns null if no tasks have a quote yet.
  static ProjectQuote? fromTasks(List<TaskItem> tasks) {
    final quoted = tasks.where((t) => t.hasQuote).toList();
    if (quoted.isEmpty) return null;

    final first = quoted.first;
    final totalMaterial =
        quoted.fold<double>(0, (s, t) => s + (t.quoteMaterial ?? 0));
    final totalLabour =
        quoted.fold<double>(0, (s, t) => s + (t.quoteLabour ?? 0));

    final agreedMaterial =
        quoted.fold<double>(0, (s, t) => s + (t.agreedMaterial ?? 0));
    final agreedLabour =
        quoted.fold<double>(0, (s, t) => s + (t.agreedLabour ?? 0));

    // Find homeowner — first participant who is not the builder
    final builderId = first.quoteBuilderId ?? '';
    final homeownerId = first.participantIds
        .firstWhere((id) => id != builderId, orElse: () => '');

    return ProjectQuote(
      builderId: builderId,
      builderName: first.quoteBuilderName ?? 'Unknown Builder',
      totalMaterial: totalMaterial,
      totalLabour: totalLabour,
      agreedMaterial: agreedMaterial,
      agreedLabour: agreedLabour,
      status: first.quoteStatus ?? 'pending',
      submittedAt: first.quoteSubmittedAt ?? DateTime.now(),
      homeownerId: homeownerId.isEmpty ? null : homeownerId,
      declineReason: first.quoteDeclineReason,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaskItem — a task document with optional quote fields
// ─────────────────────────────────────────────────────────────────────────────

class TaskItem {
  final String taskId;
  final String taskName;
  final String contractorType;
  final double? guidePrice;
  final double? guidePriceMin;
  final double? guidePriceMax;
  final int taskOrder;

  // Quote fields — null until a quote is submitted
  final String? quoteBuilderId;
  final String? quoteBuilderName;
  final double? quoteMaterial;
  final double? quoteLabour;
  final String? quoteStatus;
  final DateTime? quoteSubmittedAt;
  final double? agreedMaterial;
  final double? agreedLabour;
  final List<String> participantIds;
  final String? quoteDeclineReason;

  bool get hasQuote => quoteBuilderId != null;
  double get quoteTotal => (quoteMaterial ?? 0) + (quoteLabour ?? 0);

  const TaskItem({
    required this.taskId,
    required this.taskName,
    required this.contractorType,
    required this.guidePrice,
    required this.guidePriceMin,
    required this.guidePriceMax,
    required this.taskOrder,
    this.quoteBuilderId,
    this.quoteBuilderName,
    this.quoteMaterial,
    this.quoteLabour,
    this.quoteStatus,
    this.quoteSubmittedAt,
    this.agreedMaterial,
    this.agreedLabour,
    this.participantIds = const [],
    this.quoteDeclineReason,
  });

  factory TaskItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final meta = d['metadata'] as Map<String, dynamic>? ?? {};
    return TaskItem(
      taskId: doc.id,
      taskName: d['taskName'] ?? 'Unnamed Task',
      contractorType: d['contractorType'] ?? '',
      guidePrice: (d['guidePrice'])?.toDouble(),
      guidePriceMin: (d['guidePriceMin'])?.toDouble(),
      guidePriceMax: (d['guidePriceMax'])?.toDouble(),
      taskOrder: (meta['taskOrder'] as int?) ?? 0,
      quoteBuilderId: d['quoteBuilderId'],
      quoteBuilderName: d['quoteBuilderName'],
      quoteMaterial: (d['quoteMaterial'])?.toDouble(),
      quoteLabour: (d['quoteLabour'])?.toDouble(),
      quoteStatus: d['quoteStatus'],
      quoteSubmittedAt: _parseDate(d['quoteSubmittedAt']),
      agreedMaterial: (d['agreedMaterial'])?.toDouble(),
      agreedLabour: (d['agreedLabour'])?.toDouble(),
      participantIds: List<String>.from(d['participantIds'] ?? []),
      quoteDeclineReason: d['quoteDeclineReason'],
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}