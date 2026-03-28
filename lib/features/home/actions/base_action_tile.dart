import 'package:flutter/material.dart';
import '../models/task_model.dart';

abstract class BaseActionTile extends StatelessWidget {
  final TaskModel project;
  const BaseActionTile({super.key, required this.project});

  IconData get icon;
  String get label;
  Color get color;
  bool get isDisabled => false;
  String get disabledReason => '';
  void onTap(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDisabled ? disabledReason : '',
      child: GestureDetector(
        onTap: () => onTap(context),
        child: Opacity(
          opacity: isDisabled ? 0.4 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? Colors.grey : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}