import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primary.withOpacity(0.1);
    final txtColor = textColor ?? AppColors.primary;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: txtColor,
              ),
            )
          : null,
    );
  }
}
