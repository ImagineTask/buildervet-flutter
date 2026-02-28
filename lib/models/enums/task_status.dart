import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum TaskStatus {
  draft,
  pending,
  inProgress,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case TaskStatus.draft:
        return 'Draft';
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.draft:
        return AppColors.statusDraft;
      case TaskStatus.pending:
        return AppColors.statusPending;
      case TaskStatus.inProgress:
        return AppColors.statusInProgress;
      case TaskStatus.completed:
        return AppColors.statusCompleted;
      case TaskStatus.cancelled:
        return AppColors.statusCancelled;
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.draft:
        return Icons.edit_outlined;
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline;
      case TaskStatus.completed:
        return Icons.check_circle_outline;
      case TaskStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static TaskStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return TaskStatus.draft;
      case 'pending':
        return TaskStatus.pending;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.draft;
    }
  }
}
