import 'package:flutter/material.dart';
import '../../models/task_model.dart';

class MarketingPage extends StatelessWidget {
  final TaskModel project;

  const MarketingPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Marketing',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE056A0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 56, color: Color(0xFFE056A0)),
            SizedBox(height: 16),
            Text(
              'Marketing',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            SizedBox(height: 8),
            Text(
              'Website configuration coming soon.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
