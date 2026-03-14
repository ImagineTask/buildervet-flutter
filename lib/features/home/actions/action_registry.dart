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
import 'accept_task/accept_task_action.dart';
import 'deny_task/deny_task_action.dart';
import 'negotiate_task/negotiate_task_action.dart';

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
      case 'accept_task':
        return AcceptTaskAction(project: project);
      case 'deny_task':
        return DenyTaskAction(project: project);
      case 'negotiate_task':
        return NegotiateTaskAction(project: project);
      default:
        return null;
    }
  }

  static List<BaseActionTile> resolveAll(TaskModel project) {
    return project.actionSpace
        .map((action) => resolve(action, project))
        .whereType<BaseActionTile>()
        .toList();
  }
}
