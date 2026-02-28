enum MessageType {
  text,
  image,
  invite,
  file;

  String get label {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.image:
        return 'Image';
      case MessageType.invite:
        return 'Invite';
      case MessageType.file:
        return 'File';
    }
  }

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}
