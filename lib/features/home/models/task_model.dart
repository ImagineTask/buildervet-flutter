import 'package:cloud_firestore/cloud_firestore.dart';

/// A single model for ALL documents in the "tasks" collection.
/// taskType determines whether it's a project or a sub-task.
class TaskModel {
  final String id;
  final String taskId;
  final String taskName;
  final String description;
  final String taskType;       // "project" | "task"
  final String status;         // "draft" | "active" | "done" | etc.
  final String? parentTaskId;  // null if it's a project; set if it's a task
  final String? contractorType;
  final DateTime startTime;
  final DateTime endTime;
  final int durationDays;
  final double guidePrice;
  final double guidePriceMin;
  final double guidePriceMax;
  final List<String> actionSpace;
  final List<String> participantIds;
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
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  bool get isProject => taskType == 'project';
  bool get isTask => taskType == 'task';

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
