enum MessageType {
  text,
  image,
  invite,
  file,
  emoji;

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
      case MessageType.emoji:
        return 'Emoji';
    }
  }

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}
