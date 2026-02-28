import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/task.dart';

class ContextualActionSection extends StatelessWidget {
  final Task? selectedTask;

  const ContextualActionSection({
    super.key,
    required this.selectedTask,
  });

  @override
  Widget build(BuildContext context) {
    // No card selected — show prompt
    if (selectedTask == null) {
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

    final actions = selectedTask!.actionSpace;

    // Card selected but no actions available
    if (actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Center(
          child: Text(
            'No actions available for this item',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    // Card selected — show its actions
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
                      selectedTask!.taskName,
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
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _ActionTile(
                action: action,
                index: index,
                onTap: () {
                  // TODO: Handle action
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Single Action Tile ──────────────────────────────────

class _ActionTile extends StatelessWidget {
  final String action;
  final int index;
  final VoidCallback onTap;

  const _ActionTile({
    required this.action,
    required this.index,
    required this.onTap,
  });

  // Map action strings to icons and colors
  static final _actionConfig = <String, _ActionStyle>{
    'review_quotes': _ActionStyle(Icons.request_quote, Color(0xFFFF6B6B)),
    'approve_material': _ActionStyle(Icons.check_box, Color(0xFF4ECDC4)),
    'schedule_inspection': _ActionStyle(Icons.event, Color(0xFF45B7D1)),
    'request_inspection': _ActionStyle(Icons.verified, Color(0xFF96CEB4)),
    'upload_photo': _ActionStyle(Icons.camera_alt, Color(0xFFFECA57)),
    'add_note': _ActionStyle(Icons.note_add, Color(0xFF9B59B6)),
    'start_task': _ActionStyle(Icons.play_circle, Color(0xFF2ECC71)),
    'request_quote': _ActionStyle(Icons.receipt_long, Color(0xFFE17055)),
    'assign_contractor': _ActionStyle(Icons.person_add, Color(0xFF0984E3)),
    'mark_complete': _ActionStyle(Icons.check_circle, Color(0xFF00B894)),
    'report_issue': _ActionStyle(Icons.warning, Color(0xFFD63031)),
    'confirm_materials': _ActionStyle(Icons.inventory, Color(0xFF6C5CE7)),
    'schedule': _ActionStyle(Icons.calendar_month, Color(0xFFFD79A8)),
    'select_material': _ActionStyle(Icons.palette, Color(0xFFE84393)),
    'select_colour': _ActionStyle(Icons.color_lens, Color(0xFFA29BFE)),
    'call_engineer': _ActionStyle(Icons.phone, Color(0xFF00CEC9)),
    'approve_quote': _ActionStyle(Icons.thumb_up, Color(0xFF55A3F5)),
    'finalise_design': _ActionStyle(Icons.design_services, Color(0xFFFF9FF3)),
    'request_quotes': _ActionStyle(Icons.request_page, Color(0xFFFF6348)),
    'get_planning_advice': _ActionStyle(Icons.lightbulb, Color(0xFFF9CA24)),
    'confirm_fixtures': _ActionStyle(Icons.plumbing, Color(0xFF7ED6DF)),
  };

  // Fallback colors for unknown actions
  static const _fallbackColors = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) {
    final config = _actionConfig[action];
    final color = config?.color ?? _fallbackColors[index % _fallbackColors.length];
    final icon = config?.icon ?? Icons.bolt;

    // Format action string: "review_quotes" → "Review Quotes"
    final label = action
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
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

class _ActionStyle {
  final IconData icon;
  final Color color;
  const _ActionStyle(this.icon, this.color);
}