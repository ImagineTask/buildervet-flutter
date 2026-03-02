import 'package:flutter/material.dart';

/// Data model for a user-created custom action.
/// These don't need registration — they carry their own config.
class CustomAction {
  final String id;
  final String label;
  final String type; // 'web', 'phone', 'note'
  final String? url; // URL or phone number
  final IconData icon;
  final Color color;
  final bool shared;
  final String taskId; // which task this action belongs to

  const CustomAction({
    required this.id,
    required this.label,
    required this.type,
    this.url,
    required this.icon,
    required this.color,
    required this.shared,
    required this.taskId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'url': url,
        'icon': icon.codePoint,
        'color': color.value,
        'shared': shared,
        'taskId': taskId,
      };
}
