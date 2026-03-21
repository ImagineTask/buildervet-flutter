import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String taskId;
  final String taskName;
  final String description;
  final String taskType;
  final String status;
  final String? parentTaskId;
  final String? contractorType;
  final DateTime startTime;
  final DateTime endTime;
  final int durationDays;
  final double guidePrice;
  final double guidePriceMin;
  final double guidePriceMax;
  final List<String> actionSpace;
  final List<String> participantIds;
  final List<String> assignedBuilderIds;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  // ── Quote fields (null until a builder submits a quote) ──────────────────
  final String? quoteBuilderId;
  final String? quoteBuilderName;
  final double? quoteMaterial;
  final double? quoteLabour;
  final double? quoteTotal;
  final String? quoteStatus;
  final DateTime? quoteSubmittedAt;

  // ── Agreed fields (null until homeowner approves) ────────────────────────
  final double? agreedMaterial;
  final double? agreedLabour;
  final double? agreedTotal;
  final DateTime? agreedAt;
  final String? quoteDeclineReason;
  final String? quoteUpdateReason;

  bool get hasQuote => quoteBuilderId != null;
  bool get hasAgreedPrice => agreedTotal != null;

  TaskModel({
    required this.id,
    required this.taskId,
    required this.taskName,
    required this.description,
    required this.taskType,
    required this.status,
    this.parentTaskId,
    this.contractorType,
    required this.startTime,
    required this.endTime,
    required this.durationDays,
    required this.guidePrice,
    required this.guidePriceMin,
    required this.guidePriceMax,
    required this.actionSpace,
    required this.participantIds,
    required this.assignedBuilderIds,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
    this.quoteBuilderId,
    this.quoteBuilderName,
    this.quoteMaterial,
    this.quoteLabour,
    this.quoteTotal,
    this.quoteStatus,
    this.quoteSubmittedAt,
    this.agreedMaterial,
    this.agreedLabour,
    this.agreedTotal,
    this.agreedAt,
    this.quoteDeclineReason,
    this.quoteUpdateReason,
  });

  bool get isProject => taskType == 'project';
  bool get isTask => taskType == 'task';

  TaskModel copyWith({
    String? id,
    String? taskId,
    String? taskName,
    String? description,
    String? taskType,
    String? status,
    String? parentTaskId,
    String? contractorType,
    DateTime? startTime,
    DateTime? endTime,
    int? durationDays,
    double? guidePrice,
    double? guidePriceMin,
    double? guidePriceMax,
    List<String>? actionSpace,
    List<String>? participantIds,
    List<String>? assignedBuilderIds,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    String? quoteBuilderId,
    String? quoteBuilderName,
    double? quoteMaterial,
    double? quoteLabour,
    double? quoteTotal,
    String? quoteStatus,
    DateTime? quoteSubmittedAt,
    double? agreedMaterial,
    double? agreedLabour,
    double? agreedTotal,
    DateTime? agreedAt,
    String? quoteDeclineReason,
    String? quoteUpdateReason,
  }) {
    return TaskModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      status: status ?? this.status,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      contractorType: contractorType ?? this.contractorType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationDays: durationDays ?? this.durationDays,
      guidePrice: guidePrice ?? this.guidePrice,
      guidePriceMin: guidePriceMin ?? this.guidePriceMin,
      guidePriceMax: guidePriceMax ?? this.guidePriceMax,
      actionSpace: actionSpace ?? this.actionSpace,
      participantIds: participantIds ?? this.participantIds,
      assignedBuilderIds: assignedBuilderIds ?? this.assignedBuilderIds,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      quoteBuilderId: quoteBuilderId ?? this.quoteBuilderId,
      quoteBuilderName: quoteBuilderName ?? this.quoteBuilderName,
      quoteMaterial: quoteMaterial ?? this.quoteMaterial,
      quoteLabour: quoteLabour ?? this.quoteLabour,
      quoteTotal: quoteTotal ?? this.quoteTotal,
      quoteStatus: quoteStatus ?? this.quoteStatus,
      quoteSubmittedAt: quoteSubmittedAt ?? this.quoteSubmittedAt,
      agreedMaterial: agreedMaterial ?? this.agreedMaterial,
      agreedLabour: agreedLabour ?? this.agreedLabour,
      agreedTotal: agreedTotal ?? this.agreedTotal,
      agreedAt: agreedAt ?? this.agreedAt,
      quoteDeclineReason: quoteDeclineReason ?? this.quoteDeclineReason,
      quoteUpdateReason: quoteUpdateReason ?? this.quoteUpdateReason,
    );
  }

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      taskId: d['taskId'] ?? doc.id,
      taskName: d['taskName'] ?? '',
      description: d['description'] ?? '',
      taskType: d['taskType'] ?? 'task',
      status: d['status'] ?? 'draft',
      parentTaskId: d['parentTaskId'],
      contractorType: d['contractorType'],
      startTime: _parseDate(d['startTime']),
      endTime: _parseDate(d['endTime']),
      durationDays: d['durationDays'] ?? 0,
      guidePrice: (d['guidePrice'] ?? 0).toDouble(),
      guidePriceMin: (d['guidePriceMin'] ?? 0).toDouble(),
      guidePriceMax: (d['guidePriceMax'] ?? 0).toDouble(),
      actionSpace: List<String>.from(d['actionSpace'] ?? []),
      participantIds: List<String>.from(d['participantIds'] ?? []),
      assignedBuilderIds:
          List<String>.from(d['assignedBuilderIds'] ?? []),
      ownerId: d['ownerId'] ?? '',
      createdAt: _parseDate(d['createdAt']),
      updatedAt: _parseDate(d['updatedAt']),
      metadata: Map<String, dynamic>.from(d['metadata'] ?? {}),
      quoteBuilderId: d['quoteBuilderId'],
      quoteBuilderName: d['quoteBuilderName'],
      quoteMaterial: (d['quoteMaterial'])?.toDouble(),
      quoteLabour: (d['quoteLabour'])?.toDouble(),
      quoteTotal: (d['quoteTotal'])?.toDouble(),
      quoteStatus: d['quoteStatus'],
      quoteSubmittedAt: _parseDateNullable(d['quoteSubmittedAt']),
      agreedMaterial: (d['agreedMaterial'])?.toDouble(),
      agreedLabour: (d['agreedLabour'])?.toDouble(),
      agreedTotal: (d['agreedTotal'])?.toDouble(),
      agreedAt: _parseDateNullable(d['agreedAt']),
      quoteDeclineReason: d['quoteDeclineReason'],
      quoteUpdateReason: d['quoteUpdateReason'],
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}