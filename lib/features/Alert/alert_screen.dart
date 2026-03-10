import 'package:flutter/material.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  final List<_Alert> _alerts = [
    _Alert(title: 'Storage Almost Full', description: 'Your storage is at 80% capacity. Consider freeing up space.', time: '5 min ago', type: AlertType.warning, isRead: false),
    _Alert(title: 'New Login Detected', description: 'A new login was detected from Chrome on Windows.', time: '30 min ago', type: AlertType.security, isRead: false),
    _Alert(title: 'Meeting Starting Soon', description: 'Team Sync Meeting starts in 15 minutes.', time: '1 hour ago', type: AlertType.info, isRead: false),
    _Alert(title: 'Password Expiring', description: 'Your password will expire in 3 days. Please update it.', time: '2 hours ago', type: AlertType.warning, isRead: true),
    _Alert(title: 'Backup Successful', description: 'Your data has been backed up successfully.', time: 'Yesterday', type: AlertType.success, isRead: true),
    _Alert(title: 'System Update Available', description: 'Version 4.2.1 is available. Update now for the latest features.', time: 'Yesterday', type: AlertType.info, isRead: true),
    _Alert(title: 'Failed Login Attempt', description: '3 failed login attempts were detected on your account.', time: '2 days ago', type: AlertType.error, isRead: true),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = _alerts.where((a) => !a.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      if (unread > 0)
                        Text(
                          '$unread unread notifications',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  if (unread > 0)
                    TextButton(
                      onPressed: () => setState(() {
                        for (var a in _alerts) a.isRead = true;
                      }),
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _alerts.length,
                itemBuilder: (context, index) => _AlertCard(
                  alert: _alerts[index],
                  onTap: () => setState(() => _alerts[index].isRead = true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AlertType { warning, error, success, info, security }

class _Alert {
  final String title;
  final String description;
  final String time;
  final AlertType type;
  bool isRead;

  _Alert({
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    required this.isRead,
  });
}

extension _AlertTypeExtension on AlertType {
  Color get color {
    switch (this) {
      case AlertType.warning: return const Color(0xFFFFB347);
      case AlertType.error: return const Color(0xFFFF6B6B);
      case AlertType.success: return const Color(0xFF43C59E);
      case AlertType.info: return const Color(0xFF6C63FF);
      case AlertType.security: return const Color(0xFFE056A0);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.warning: return Icons.warning_amber_outlined;
      case AlertType.error: return Icons.error_outline;
      case AlertType.success: return Icons.check_circle_outline;
      case AlertType.info: return Icons.info_outline;
      case AlertType.security: return Icons.security_outlined;
    }
  }

  String get label {
    switch (this) {
      case AlertType.warning: return 'Warning';
      case AlertType.error: return 'Error';
      case AlertType.success: return 'Success';
      case AlertType.info: return 'Info';
      case AlertType.security: return 'Security';
    }
  }
}

class _AlertCard extends StatelessWidget {
  final _Alert alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = alert.type.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: alert.isRead
              ? null
              : Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(alert.type.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alert.type.label,
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alert.time,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
