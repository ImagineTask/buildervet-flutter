import 'package:flutter/material.dart';

class TaskEvent {
  final String id;
  final String type;
  final DateTime timestamp;
  final String actorId;
  final String actorName;
  final String actorRole;
  final Map<String, dynamic> data;

  const TaskEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    this.data = const {},
  });

  String get label {
    switch (type) {
      case 'task_created':
        return 'Task created';
      case 'quote_submitted':
        final amount = data['amount'];
        return amount != null ? 'Quote submitted (\u00A3${_formatNum(amount)})' : 'Quote submitted';
      case 'quote_accepted':
        final amount = data['amount'];
        final contractor = data['contractorName'] ?? '';
        return amount != null ? 'Quote accepted (\u00A3${_formatNum(amount)}) — $contractor' : 'Quote accepted';
      case 'quote_rejected':
        return 'Quote rejected';
      case 'person_assigned':
        final name = data['personName'] ?? 'Someone';
        final role = data['personRole'] ?? '';
        return '$name assigned${role.isNotEmpty ? ' ($role)' : ''}';
      case 'person_removed':
        final name = data['personName'] ?? 'Someone';
        return '$name removed';
      case 'work_scheduled':
        final start = data['startDate'] ?? '';
        final end = data['endDate'] ?? '';
        return 'Work scheduled ($start — $end)';
      case 'work_started':
        return 'Work started';
      case 'work_paused':
        return 'Work paused';
      case 'work_resumed':
        return 'Work resumed';
      case 'photo_uploaded':
        final count = data['count'] ?? 1;
        return count > 1 ? '$count photos uploaded' : 'Photo uploaded';
      case 'inspection_requested':
        return 'Inspection requested';
      case 'inspection_passed':
        return 'Inspection passed';
      case 'inspection_failed':
        final reason = data['reason'] ?? '';
        return 'Inspection failed${reason.isNotEmpty ? ' — $reason' : ''}';
      case 'invoice_created':
        final amount = data['amount'];
        return amount != null ? 'Invoice created (\u00A3${_formatNum(amount)})' : 'Invoice created';
      case 'invoice_sent':
        return 'Invoice sent';
      case 'payment_received':
        return 'Payment received';
      case 'task_completed':
        return 'Task completed';
      case 'status_changed':
        final to = data['to'] ?? '';
        return 'Status changed to $to';
      case 'note_added':
        final note = data['note'] ?? '';
        return note.length > 50 ? 'Note: ${note.substring(0, 50)}...' : 'Note: $note';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  IconData get icon {
    switch (type) {
      case 'task_created':
        return Icons.add_circle_outline;
      case 'quote_submitted':
        return Icons.request_quote;
      case 'quote_accepted':
        return Icons.check_circle;
      case 'quote_rejected':
        return Icons.cancel_outlined;
      case 'person_assigned':
        return Icons.person_add;
      case 'person_removed':
        return Icons.person_remove;
      case 'work_scheduled':
        return Icons.calendar_month;
      case 'work_started':
        return Icons.construction;
      case 'work_paused':
        return Icons.pause_circle_outline;
      case 'work_resumed':
        return Icons.play_circle_outline;
      case 'photo_uploaded':
        return Icons.camera_alt;
      case 'inspection_requested':
        return Icons.verified_outlined;
      case 'inspection_passed':
        return Icons.verified;
      case 'inspection_failed':
        return Icons.warning_amber;
      case 'invoice_created':
        return Icons.receipt_long;
      case 'invoice_sent':
        return Icons.send;
      case 'payment_received':
        return Icons.payments;
      case 'task_completed':
        return Icons.celebration;
      case 'status_changed':
        return Icons.flag_circle;
      case 'note_added':
        return Icons.note_add;
      default:
        return Icons.circle;
    }
  }

  Color get color {
    switch (type) {
      case 'task_created':
        return const Color(0xFF6366F1);
      case 'quote_submitted':
        return const Color(0xFFFF6B6B);
      case 'quote_accepted':
        return const Color(0xFF00B894);
      case 'quote_rejected':
        return const Color(0xFFD63031);
      case 'person_assigned':
        return const Color(0xFF45B7D1);
      case 'person_removed':
        return const Color(0xFFE17055);
      case 'work_scheduled':
        return const Color(0xFF45B7D1);
      case 'work_started':
      case 'work_resumed':
        return const Color(0xFFFECA57);
      case 'work_paused':
        return const Color(0xFFE17055);
      case 'photo_uploaded':
        return const Color(0xFFFECA57);
      case 'inspection_requested':
        return const Color(0xFFE17055);
      case 'inspection_passed':
        return const Color(0xFF00B894);
      case 'inspection_failed':
        return const Color(0xFFD63031);
      case 'invoice_created':
      case 'invoice_sent':
        return const Color(0xFF6C5CE7);
      case 'payment_received':
        return const Color(0xFF00B894);
      case 'task_completed':
        return const Color(0xFF00B894);
      case 'status_changed':
        return const Color(0xFF6366F1);
      case 'note_added':
        return const Color(0xFF45B7D1);
      default:
        return const Color(0xFF636E72);
    }
  }

  static String _formatNum(dynamic value) {
    if (value is int) return value.toString();
    if (value is double) {
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(2);
    }
    return value.toString();
  }

  factory TaskEvent.fromJson(Map<String, dynamic> json) {
    return TaskEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      actorId: json['actorId'] as String,
      actorName: json['actorName'] as String,
      actorRole: json['actorRole'] as String,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'actorId': actorId,
        'actorName': actorName,
        'actorRole': actorRole,
        'data': data,
      };
}
