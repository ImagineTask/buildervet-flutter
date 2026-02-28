import 'enums/participant_role.dart';

class Participant {
  final String userId;
  final String name;
  final ParticipantRole role;
  final String email;
  final String? avatarUrl;
  final String? phone;

  const Participant({
    required this.userId,
    required this.name,
    required this.role,
    required this.email,
    this.avatarUrl,
    this.phone,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      userId: json['userId'] as String,
      name: json['name'] as String,
      role: ParticipantRole.fromString(json['role'] as String),
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'role': role.name,
      'email': email,
      'avatarUrl': avatarUrl,
      'phone': phone,
    };
  }

  Participant copyWith({
    String? userId,
    String? name,
    ParticipantRole? role,
    String? email,
    String? avatarUrl,
    String? phone,
  }) {
    return Participant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
    );
  }
}
