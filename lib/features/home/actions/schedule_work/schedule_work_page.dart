import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import 'task_schedule_detail_page.dart';
import 'task_schedule_card.dart';

class ScheduleWorkPage extends StatelessWidget {
  final TaskModel project;

  const ScheduleWorkPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          project.taskName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('parentTaskId', isEqualTo: project.id)
            .where('taskType', isEqualTo: 'task')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No tasks found for this project.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final tasks = snapshot.data!.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return TaskScheduleCard(
                task: tasks[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TaskScheduleDetailPage(task: tasks[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}