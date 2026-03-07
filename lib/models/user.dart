class AppUser {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? company;

  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.company,
  });

  /// First name for greeting
  String get firstName {
    final parts = name.split(' ');
    return parts.first;
  }

  /// Initials for avatar fallback
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['userId'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      phone: json['phone'] as String?,
      company: json['company'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'role': role,
        'avatarUrl': avatarUrl,
        'phone': phone,
        'company': company,
      };
}
