enum MessageType {
  text,
  image,
  invite,
  file,
  emoji,
  video,
  audio,
  voice,
  document;

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
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.voice:
        return 'Voice';
      case MessageType.document:
        return 'Document';
    }
  }

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}
