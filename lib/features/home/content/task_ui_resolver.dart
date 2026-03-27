import 'package:flutter/material.dart';
import '../../home/models/task_model.dart';
import '../../Cards/Task/task_assigned_type_card.dart';
import '../../Cards/Task/generic_domain_task_card.dart';
// import '../../Cards/Task/shift_task_card.dart';
// import '../../Cards/Task/training_task_card.dart';

class TaskUIResolver {
  static Widget getCard(TaskModel task) {
    final moduleType = task.moduleType;
    
    switch (moduleType) {
      case 'daily_shift':
        // return ShiftTaskCard(task: task);
        return GenericDomainTaskCard(task: task); // Placeholder until ShiftTaskCard is fleshed out
      case 'staff_training':
        // return TrainingTaskCard(task: task);
        return GenericDomainTaskCard(task: task); // Placeholder
      case 'order_management':
        return GenericDomainTaskCard(task: task);
      default:
        // Use exact original cards if domain is homeServices (or null legacy)
        if (task.domainId == 'home_services' || task.domainId == null) {
          return TaskAssignedTypeCard(task: task);
        }
        // General fallback for any new domains
        return GenericDomainTaskCard(task: task);
    }
  }
}
