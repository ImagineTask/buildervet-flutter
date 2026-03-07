import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/task.dart';
import '../../actions/action_registry.dart';
import '../../actions/action_router.dart';
import '../../actions/models/custom_action.dart';
import '../../actions/sheets/add_custom_action_sheet.dart';

class ContextualActionSection extends StatefulWidget {
  final Task? selectedTask;

  const ContextualActionSection({
    super.key,
    required this.selectedTask,
  });

  @override
  State<ContextualActionSection> createState() =>
      _ContextualActionSectionState();
}

class _ContextualActionSectionState extends State<ContextualActionSection> {
  /// Custom actions created by the user, keyed by taskId
  final Map<String, List<CustomAction>> _customActions = {};

  /// Get custom actions for the currently selected task
  List<CustomAction> get _currentCustomActions {
    if (widget.selectedTask == null) return [];
    return _customActions[widget.selectedTask!.taskId] ?? [];
  }

  /// Show the add custom action sheet and handle the result
  Future<void> _showAddCustomActionSheet() async {
    final action = await showModalBottomSheet<CustomAction>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddCustomActionSheet(task: widget.selectedTask!),
    );

    if (action != null) {
      setState(() {
        _customActions
            .putIfAbsent(action.taskId, () => [])
            .add(action);
      });
      // TODO: Persist to local storage or backend
    }
  }

  /// Delete a custom action
  void _deleteCustomAction(CustomAction action) {
    setState(() {
      _customActions[action.taskId]?.remove(action);
    });
  }

  /// Handle tap on a custom action tile
  void _handleCustomActionTap(CustomAction action) {
    switch (action.type) {
      case 'web':
        if (action.url != null && action.url!.isNotEmpty) {
          ActionRouter.openCustomAction(context, {
            'label': action.label,
            'type': 'web',
            'url': action.url,
          }, widget.selectedTask!);
        }
        break;
      case 'phone':
        // TODO: Launch phone dialer with action.url
        break;
      case 'note':
        // TODO: Open note editor
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // No card selected — show prompt
    if (widget.selectedTask == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 40,
                color: AppColors.textTertiary.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Select a card to take actions',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final systemActions = widget.selectedTask!.actionSpace;
    final customActions = _currentCustomActions;
    // Total tiles = system actions + custom actions + 1 "Add" tile
    final totalCount = systemActions.length + customActions.length + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.selectedTask!.taskName,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Reorder actions
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Reorder',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action tiles grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.1,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              // System action tiles
              if (index < systemActions.length) {
                final actionKey = systemActions[index];
                final config = _getActionConfig(actionKey, index);

                return _ActionTile(
                  config: config,
                  onTap: () {
                    _handleActionTap(context, actionKey, widget.selectedTask!);
                  },
                );
              }

              // Custom action tiles
              final customIndex = index - systemActions.length;
              if (customIndex < customActions.length) {
                final custom = customActions[customIndex];

                return _CustomActionTile(
                  action: custom,
                  onTap: () => _handleCustomActionTap(custom),
                  onLongPress: () => _showCustomActionOptions(custom),
                );
              }

              // Last tile = "+" add action
              return _AddActionTile(
                onTap: _showAddCustomActionSheet,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Show edit/delete options for a custom action
  void _showCustomActionOptions(CustomAction action) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                action.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(action.icon, color: action.color, size: 20),
                ),
                title: const Text('Open Action'),
                subtitle: Text(
                  action.type == 'web'
                      ? action.url ?? 'No URL'
                      : action.type == 'phone'
                          ? action.url ?? 'No number'
                          : 'Note',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleCustomActionTap(action);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(Icons.delete, color: AppColors.error, size: 20),
                ),
                title: const Text('Delete Action'),
                subtitle: Text(
                  'Remove this custom action',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(action);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirm before deleting
  void _confirmDelete(CustomAction action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: const Text('Delete Action?'),
        content: Text(
          'Remove "${action.label}" from your quick actions?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteCustomAction(action);
    }
  }

  /// Get config from registry, or generate fallback.
  /// All system keys (including backend action_space keys) are registered
  /// in ActionRegistry, so this only falls back for truly unknown keys.
  ActionConfig _getActionConfig(String actionKey, int index) {
    final registered = ActionRegistry.get(actionKey);
    if (registered != null) return registered;
    return ActionRegistry.fallback(actionKey, index: index);
  }

  /// Route tap to the correct screen.
  /// For project tasks, certain action keys are handled project-wide
  /// (navigating across all tasks). Both legacy 'project_*' keys and the
  /// backend's direct keys (view_tasks, review_quotes, etc.) are supported.
  void _handleActionTap(BuildContext context, String actionKey, Task task) {
    const projectLevelKeys = {
      // legacy frontend keys
      'project_detail', 'project_quote', 'project_schedule',
      'project_photo', 'project_invoice',
      // backend project_action_space keys
      'view_tasks', 'view_progress', 'manage_team', 'create_invoice',
      // review_quotes and upload_photo are shared but on a project we open
      // the project-scoped version
    };

    final isProject = task.isProject;

    if (isProject && (projectLevelKeys.contains(actionKey) ||
        actionKey == 'review_quotes' ||
        actionKey == 'upload_photo' ||
        actionKey == 'schedule_work')) {
      ActionRouter.openProjectAction(context, actionKey, task);
      return;
    }

    ActionRouter.open(context, actionKey, task);
  }
}

// ─── System Action Tile ──────────────────────────────────

class _ActionTile extends StatelessWidget {
  final ActionConfig config;
  final VoidCallback onTap;

  const _ActionTile({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: config.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: config.color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(config.icon, color: config.color, size: 24),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                config.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Action Tile ──────────────────────────────────

class _CustomActionTile extends StatelessWidget {
  final CustomAction action;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CustomActionTile({
    required this.action,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: action.color.withOpacity(0.15)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(action.icon, color: action.color, size: 24),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Small indicator that this is a custom action
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: action.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Action Tile (the "+" button) ────────────────────

class _AddActionTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddActionTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                Icons.add,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add Action',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}