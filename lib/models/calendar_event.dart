import 'package:flutter/material.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String? taskId;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? description;
  final CalendarEventType type;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.taskId,
    required this.date,
    this.startTime,
    this.endTime,
    this.description,
    required this.type,
  });
}

enum CalendarEventType {
  taskStart,
  taskEnd,
  inspection,
  delivery,
  meeting,
  milestone;

  String get label {
    switch (this) {
      case CalendarEventType.taskStart:
        return 'Task Start';
      case CalendarEventType.taskEnd:
        return 'Task End';
      case CalendarEventType.inspection:
        return 'Inspection';
      case CalendarEventType.delivery:
        return 'Delivery';
      case CalendarEventType.meeting:
        return 'Meeting';
      case CalendarEventType.milestone:
        return 'Milestone';
    }
  }
}
