class Alert {
  final String id;
  final String title;
  final String body;
  final String? taskId;
  final DateTime createdAt;
  final bool isRead;
  final AlertType type;

  const Alert({
    required this.id,
    required this.title,
    required this.body,
    this.taskId,
    required this.createdAt,
    this.isRead = false,
    required this.type,
  });

  Alert copyWith({bool? isRead}) {
    return Alert(
      id: id,
      title: title,
      body: body,
      taskId: taskId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }
}

enum AlertType {
  quoteReceived,
  taskUpdated,
  taskCompleted,
  messageReceived,
  paymentDue,
  reminder;

  String get label {
    switch (this) {
      case AlertType.quoteReceived:
        return 'New Quote';
      case AlertType.taskUpdated:
        return 'Task Updated';
      case AlertType.taskCompleted:
        return 'Task Completed';
      case AlertType.messageReceived:
        return 'New Message';
      case AlertType.paymentDue:
        return 'Payment Due';
      case AlertType.reminder:
        return 'Reminder';
    }
  }
}
