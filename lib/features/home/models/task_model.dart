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
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}