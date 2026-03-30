import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task_model.dart';

class AddTaskSheet extends StatefulWidget {
  final TaskModel project;
  final int nextOrderNumber;

  const AddTaskSheet({
    super.key,
    required this.project,
    required this.nextOrderNumber,
  });

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contractorTypeController = TextEditingController();
  final _guidePriceMinController = TextEditingController();
  final _guidePriceMaxController = TextEditingController();
  final _durationDaysController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _taskNameController.dispose();
    _descriptionController.dispose();
    _contractorTypeController.dispose();
    _guidePriceMinController.dispose();
    _guidePriceMaxController.dispose();
    _durationDaysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now().toUtc().toIso8601String();
      final taskId = 'task-${DateTime.now().millisecondsSinceEpoch}';
      final priceMin =
          double.tryParse(_guidePriceMinController.text.trim()) ?? 0;
      final priceMax =
          double.tryParse(_guidePriceMaxController.text.trim()) ?? 0;
      final durationDays =
          int.tryParse(_durationDaysController.text.trim()) ?? 1;
      final guidePrice = (priceMin + priceMax) / 2;

      final batch = firestore.batch();

      // Create task document
      final taskRef = firestore.collection('tasks').doc(taskId);
      batch.set(taskRef, {
        'taskId': taskId,
        'taskName': _taskNameController.text.trim(),
        'taskType': 'task',
        'parentTaskId': widget.project.taskId,
        'description': _descriptionController.text.trim(),
        'status': 'unassigned',
        'actionSpace': [],
        'contractorType': _contractorTypeController.text.trim(),
        'guidePrice': guidePrice,
        'guidePriceMin': priceMin,
        'guidePriceMax': priceMax,
        'durationDays': durationDays,
        'startTime': now,
        'endTime': now,
        'ownerId': widget.project.ownerId,
        'participantIds': [widget.project.ownerId],
        'assignedBuilderIds': [],
        'metadata': {
          'taskOrder': widget.nextOrderNumber,
        },
        'createdAt': now,
        'updatedAt': now,
      });

      // Write task_created event
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';
      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'task_created',
        'timestamp': now,
        'actorId': currentUser?.uid ?? widget.project.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'homeowner',
        'data': {
          'note': 'Task manually added by project owner',
        },
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task added successfully'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Task',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${widget.nextOrderNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.project.taskName,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task name
                      _label('Task Name *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _taskNameController,
                        decoration: _inputDecoration('e.g. Electrical Second Fix'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Task name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _label('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                            'Describe what this task involves...'),
                      ),
                      const SizedBox(height: 16),

                      // Contractor type
                      _label('Contractor Type'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contractorTypeController,
                        decoration:
                            _inputDecoration('e.g. Electrician, Plumber'),
                      ),
                      const SizedBox(height: 16),

                      // Duration days
                      _label('Duration (days) *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _durationDaysController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('e.g. 3'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Duration is required';
                          }
                          if (int.tryParse(v.trim()) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Guide price range
                      _label('Guide Price Range'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _guidePriceMinController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Min'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('–',
                              style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _guidePriceMaxController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Max'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Add Task',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}