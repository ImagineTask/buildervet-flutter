import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/layout/section_header.dart';

class ActionAreaSection extends StatelessWidget {
  const ActionAreaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.1,
            children: const [
              _ActionTile(
                icon: Icons.add_task,
                label: 'New Task',
                color: AppColors.primary,
              ),
              _ActionTile(
                icon: Icons.request_quote,
                label: 'Get Quotes',
                color: AppColors.secondary,
              ),
              _ActionTile(
                icon: Icons.person_add,
                label: 'Add Person',
                color: AppColors.success,
              ),
              _ActionTile(
                icon: Icons.auto_awesome,
                label: 'AI Estimate',
                color: AppColors.accent,
              ),
              _ActionTile(
                icon: Icons.camera_alt,
                label: 'Upload Photo',
                color: AppColors.info,
              ),
              _ActionTile(
                icon: Icons.description,
                label: 'Documents',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Handle action
      },
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
