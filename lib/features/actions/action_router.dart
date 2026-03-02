import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/task.dart';
import 'action_registry.dart';
import 'screens/project_task_list_screen.dart';

/// Routes action tile taps to the correct destination.
/// Handles system actions (from registry) and custom user actions.
class ActionRouter {
  ActionRouter._();

  /// Open a system action by key
  static void open(BuildContext context, String actionKey, Task task) {
    final config = ActionRegistry.get(actionKey);

    if (config == null) {
      // Unregistered action — show placeholder
      _openPlaceholder(context, actionKey, task);
      return;
    }

    switch (config.displayMode) {
      case ActionDisplayMode.fullScreen:
        _openFullScreen(context, config, task);
        break;
      case ActionDisplayMode.bottomSheet:
        _openBottomSheet(context, config, task);
        break;
      case ActionDisplayMode.webView:
        _openWebView(context, config, task);
        break;
    }
  }

  /// Open a project-specific action (Detail, Quote, Schedule, Photo, Invoice)
  static void openProjectAction(
    BuildContext context,
    String actionKey,
    Task project,
  ) {
    switch (actionKey) {
      case 'project_detail':
        context.push(
          '/actions/project-tasks/${project.taskId}/detail',
        );
        break;
      case 'project_quote':
        context.push(
          '/actions/project-tasks/${project.taskId}/quote',
        );
        break;
      case 'project_schedule':
        context.push(
          '/actions/project-tasks/${project.taskId}/schedule',
        );
        break;
      case 'project_photo':
        context.push(
          '/actions/project-photo/${project.taskId}',
        );
        break;
      case 'project_invoice':
        context.push(
          '/actions/project-tasks/${project.taskId}/invoice',
        );
        break;
      default:
        // Fall back to regular action handling
        open(context, actionKey, project);
    }
  }

  /// Open a custom user action (URL, phone, note)
  static void openCustomAction(
    BuildContext context,
    Map<String, dynamic> actionData,
    Task task,
  ) {
    final type = actionData['type'] as String? ?? 'web';

    switch (type) {
      case 'web':
        final url = actionData['url'] as String?;
        if (url != null && url.isNotEmpty) {
          context.push('/actions/webview', extra: {
            'url': url,
            'title': actionData['label'] ?? 'Web',
          });
        }
        break;
      case 'phone':
        // TODO: Launch phone dialer
        break;
      case 'note':
        // TODO: Open note viewer
        break;
    }
  }

  // ─── Private Helpers ─────────────────────────────────────

  static void _openFullScreen(
    BuildContext context,
    ActionConfig config,
    Task task,
  ) {
    // Route to the specific screen based on action key
    switch (config.key) {
      case 'review_quotes':
        context.push('/actions/task-quote/${task.taskId}');
        break;
      case 'request_quote':
      case 'request_quotes':
        // TODO: Build request quote screen
        _openPlaceholder(context, config.key, task);
        break;
      case 'assign_contractor':
        // TODO: Build assign contractor screen
        _openPlaceholder(context, config.key, task);
        break;
      case 'report_issue':
        // TODO: Build report issue screen
        _openPlaceholder(context, config.key, task);
        break;
      case 'approve_material':
        // TODO: Build approve material screen
        _openPlaceholder(context, config.key, task);
        break;
      case 'finalise_design':
        // TODO: Build finalise design screen
        _openPlaceholder(context, config.key, task);
        break;
      default:
        _openPlaceholder(context, config.key, task);
    }
  }

  static void _openBottomSheet(
    BuildContext context,
    ActionConfig config,
    Task task,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        switch (config.screenType) {
          case ActionScreenType.confirmation:
            return _ConfirmationSheet(config: config, task: task);
          case ActionScreenType.textInput:
            return _TextInputSheet(config: config, task: task);
          case ActionScreenType.form:
            return _FormSheet(config: config, task: task);
          case ActionScreenType.phone:
            return _PhoneSheet(config: config, task: task);
          default:
            return _PlaceholderSheet(config: config);
        }
      },
    );
  }

  static void _openWebView(
    BuildContext context,
    ActionConfig config,
    Task task,
  ) {
    final url = config.url ?? '';
    if (url.isNotEmpty) {
      context.push('/actions/webview', extra: {
        'url': url,
        'title': config.label,
      });
    }
  }

  static void _openPlaceholder(
    BuildContext context,
    String actionKey,
    Task task,
  ) {
    final config = ActionRegistry.get(actionKey) ??
        ActionRegistry.fallback(actionKey);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PlaceholderSheet(config: config),
    );
  }
}

// ─── Generic Bottom Sheets ───────────────────────────────

class _ConfirmationSheet extends StatelessWidget {
  final ActionConfig config;
  final Task task;

  const _ConfirmationSheet({required this.config, required this.task});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              config.label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              config.confirmMessage ?? 'Are you sure?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Show task name for context
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.taskName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: Execute the action
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(backgroundColor: config.color),
                    child: Text(config.confirmLabel ?? 'Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TextInputSheet extends StatefulWidget {
  final ActionConfig config;
  final Task task;

  const _TextInputSheet({required this.config, required this.task});

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.config.label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.task.taskName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type your note here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // TODO: Save the note
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: widget.config.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSheet extends StatelessWidget {
  final ActionConfig config;
  final Task task;

  const _FormSheet({required this.config, required this.task});

  @override
  Widget build(BuildContext context) {
    final fields = config.formFields ?? [];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              config.label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              task.taskName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...fields.map((field) {
              final label = field['label'] as String? ?? field['name'] as String;
              final type = field['type'] as String? ?? 'text';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: label,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: type == 'date'
                        ? const Icon(Icons.calendar_today, size: 18)
                        : type == 'time'
                            ? const Icon(Icons.access_time, size: 18)
                            : null,
                  ),
                  readOnly: type == 'date' || type == 'time',
                  onTap: () {
                    if (type == 'date') {
                      // TODO: Show date picker
                    } else if (type == 'time') {
                      // TODO: Show time picker
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // TODO: Submit form
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: config.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneSheet extends StatelessWidget {
  final ActionConfig config;
  final Task task;

  const _PhoneSheet({required this.config, required this.task});

  @override
  Widget build(BuildContext context) {
    final participants = task.participants;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              config.label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (participants.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No contacts available for this task',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ...participants.map((p) => ListTile(
                    leading: CircleAvatar(
                      child: Text(p.name.isNotEmpty ? p.name[0] : '?'),
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.role.label),
                    trailing: IconButton(
                      icon: Icon(Icons.phone, color: config.color),
                      onPressed: () {
                        // TODO: Launch phone dialer with p.phone
                        Navigator.pop(context);
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderSheet extends StatelessWidget {
  final ActionConfig config;

  const _PlaceholderSheet({required this.config});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              config.label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is coming soon',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
