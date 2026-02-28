import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/task.dart';
import '../../../shared/widgets/badges/status_badge.dart';

class CardCarouselSection extends StatefulWidget {
  final List<Task> items;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onSeeAll;

  const CardCarouselSection({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.onSeeAll,
  });

  @override
  State<CardCarouselSection> createState() => _CardCarouselSectionState();
}

class _CardCarouselSectionState extends State<CardCarouselSection>
    with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentPage = 0;
  bool _userIsSwiping = false;

  int _findSelectedIndex() {
    if (widget.selectedId == null) return 0;
    final index = widget.items.indexWhere((t) => t.taskId == widget.selectedId);
    return index >= 0 ? index : 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPage = _findSelectedIndex();
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: _currentPage,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes, snap back to selected card
    if (state == AppLifecycleState.resumed) {
      _snapToSelected();
    }
  }

  @override
  void didUpdateWidget(CardCarouselSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If selection changed (e.g. from "See all" screen), scroll to it
    if (widget.selectedId != oldWidget.selectedId && widget.selectedId != null) {
      _snapToSelected();
    }
  }

  /// Animate the carousel back to the selected card
  void _snapToSelected() {
    if (widget.selectedId == null) return;
    final targetIndex = _findSelectedIndex();
    if (targetIndex != _currentPage && _pageController.hasClients) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Called when user stops swiping — if there's a selected card,
  /// snap back after a short delay
  void _onScrollEnd() {
    if (widget.selectedId != null && _currentPage != _findSelectedIndex()) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && widget.selectedId != null) {
          _snapToSelected();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// Show confirmation dialog before selecting a card
  Future<void> _confirmSelection(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                task.isProject ? Icons.folder : Icons.task_alt,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select ${task.isProject ? "Project" : "Task"}?',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.taskName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  DateUtils2.dateRange(task.startTime, task.endTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (task.guidePrice != null) ...[
                  const Spacer(),
                  Text(
                    CurrencyUtils.formatPriceCompact(task.guidePrice!),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onSelect(task.taskId);
    }
  }

  /// Show confirmation dialog before deselecting a card
  Future<void> _confirmDeselection(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.deselect,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Deselect this item?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'You are about to deselect "${task.taskName}". The quick actions for this item will be hidden.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep selected',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Deselect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onSelect(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Nothing here yet',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Carousel
        SizedBox(
          height: 200,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification) {
                _onScrollEnd();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = item.taskId == widget.selectedId;

                return GestureDetector(
                  onTap: () {
                    if (isSelected) {
                      _confirmDeselection(item);
                    } else {
                      _confirmSelection(item);
                    }
                  },
                  child: _CarouselCard(
                    task: item,
                    isSelected: isSelected,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Page indicator dots + See all
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              // Dots
              if (widget.items.length > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.items.length > 5 ? 5 : widget.items.length,
                    (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textTertiary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
              const Spacer(),
              // See all
              TextButton(
                onPressed: widget.onSeeAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Single Carousel Card ────────────────────────────────

class _CarouselCard extends StatelessWidget {
  final Task task;
  final bool isSelected;

  const _CarouselCard({
    required this.task,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: initial + status/selected
          Row(
            children: [
              Text(
                task.taskName.isNotEmpty ? task.taskName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : task.status.color,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                )
              else
                StatusBadge(status: task.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Task name (shown when selected for clarity)
          if (isSelected)
            Text(
              task.taskName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // Description
          Text(
            task.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: isSelected ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),

          // Bottom row: date + selected badge / price
          Row(
            children: [
              // Date chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      DateUtils2.formatDateTime(task.startTime),
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Tap hint for unselected cards
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to select',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}