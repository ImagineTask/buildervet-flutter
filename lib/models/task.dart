import 'enums/task_type.dart';
import 'enums/task_status.dart';
import 'quote.dart';
import 'participant.dart';
import 'task_event.dart';

class Task {
  final String taskId;
  final String taskName;
  final TaskType taskType;
  final String? parentTaskId;
  final DateTime startTime;
  final DateTime endTime;
  final String description;
  final TaskStatus status;
  final List<String> actionSpace;
  final double? guidePrice;
  final List<Quote> quotes;
  final List<Participant> participants;
  final List<TaskEvent> events;
  final Map<String, dynamic> metadata;

  const Task({
    required this.taskId,
    required this.taskName,
    required this.taskType,
    this.parentTaskId,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.status,
    this.actionSpace = const [],
    this.guidePrice,
    this.quotes = const [],
    this.participants = const [],
    this.events = const [],
    this.metadata = const {},
  });

  bool get isProject => taskType == TaskType.project;

  bool get hasParent => parentTaskId != null;

  Quote? get acceptedQuote {
    try {
      return quotes.firstWhere((q) => q.status.name == 'accepted');
    } catch (_) {
      return null;
    }
  }

  int get pendingQuoteCount =>
      quotes.where((q) => q.status.name == 'pending').length;

  int get durationDays => endTime.difference(startTime).inDays;

  /// Events sorted newest first
  List<TaskEvent> get eventsSorted {
    final sorted = List<TaskEvent>.from(events);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  /// Events sorted oldest first (chronological)
  List<TaskEvent> get eventsChronological {
    final sorted = List<TaskEvent>.from(events);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: json['taskId'] as String,
      taskName: json['taskName'] as String,
      taskType: TaskType.fromString(json['taskType'] as String),
      parentTaskId: json['parentTaskId'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      description: json['description'] as String,
      status: TaskStatus.fromString(json['status'] as String),
      actionSpace: List<String>.from(json['actionSpace'] ?? []),
      guidePrice: (json['guidePrice'] as num?)?.toDouble(),
      quotes: (json['quotes'] as List<dynamic>?)
              ?.map((q) => Quote.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => Participant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => TaskEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskName': taskName,
      'taskType': taskType.name,
      'parentTaskId': parentTaskId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'description': description,
      'status': status.name,
      'actionSpace': actionSpace,
      'guidePrice': guidePrice,
      'quotes': quotes.map((q) => q.toJson()).toList(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'metadata': metadata,
    };
  }

  Task copyWith({
    String? taskId,
    String? taskName,
    TaskType? taskType,
    String? parentTaskId,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    TaskStatus? status,
    List<String>? actionSpace,
    double? guidePrice,
    List<Quote>? quotes,
    List<Participant>? participants,
    List<TaskEvent>? events,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      taskType: taskType ?? this.taskType,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      status: status ?? this.status,
      actionSpace: actionSpace ?? this.actionSpace,
      guidePrice: guidePrice ?? this.guidePrice,
      quotes: quotes ?? this.quotes,
      participants: participants ?? this.participants,
      events: events ?? this.events,
      metadata: metadata ?? this.metadata,
    );
  }
}