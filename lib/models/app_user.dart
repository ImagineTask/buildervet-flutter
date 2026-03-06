class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? company;
  final String? avatarUrl;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.company,
    this.avatarUrl,
    required this.createdAt,
  });

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'homeowner',
      phone: json['phone'] as String?,
      company: json['company'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'company': company,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
      };
}
