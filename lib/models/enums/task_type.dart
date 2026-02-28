enum TaskType {
  project,
  task;

  String get label {
    switch (this) {
      case TaskType.project:
        return 'Project';
      case TaskType.task:
        return 'Task';
    }
  }

  static TaskType fromString(String value) {
    return TaskType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskType.task,
    );
  }
}
