import 'package:flutter/material.dart';
import '../models/task_model.dart';
import 'base_action_tile.dart';
import 'view_tasks/view_tasks_action.dart';
import 'review_quotes/review_quotes_action.dart';
import 'schedule_work/schedule_work_action.dart';
import 'upload_photo/upload_photo_action.dart';
import 'view_progress/view_progress_action.dart';
import 'manage_team/manage_team_action.dart';
import 'create_invoice/create_invoice_action.dart';
import 'request_quote/request_quote_action.dart';
import 'view_details/view_details_action.dart';
import 'add_note/add_note_action.dart';

/// Maps an action string (from Firestore actionSpace) to its tile widget.
/// To add a new action:
///   1. Create a new subfolder under widgets/actions/
///   2. Create your action class extending BaseActionTile
///   3. Register it here with its action string key
class ActionRegistry {
  ActionRegistry._();

  static BaseActionTile? resolve(String action, TaskModel project) {
    switch (action) {
      case 'view_tasks':
        return ViewTasksAction(project: project);
      case 'review_quotes':
        return ReviewQuotesAction(project: project);
      case 'schedule_work':
        return ScheduleWorkAction(project: project);
      case 'upload_photo':
        return UploadPhotoAction(project: project);
      case 'view_progress':
        return ViewProgressAction(project: project);
      case 'manage_team':
        return ManageTeamAction(project: project);
      case 'create_invoice':
        return CreateInvoiceAction(project: project);
      case 'request_quote':
        return RequestQuoteAction(project: project);
      case 'view_details':
        return ViewDetailsAction(project: project);
      case 'add_note':
        return AddNoteAction(project: project);
      default:
        // Unknown action — returns null, caller can skip or show fallback
        return null;
    }
  }

  /// Resolves all actions for a project, skipping unknown ones.
  static List<BaseActionTile> resolveAll(TaskModel project) {
    return project.actionSpace
        .map((action) => resolve(action, project))
        .whereType<BaseActionTile>()
        .toList();
  }
}
