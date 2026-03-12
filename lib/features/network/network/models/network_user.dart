import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkUser {
  final String uid;
  final String name;
  final String email;
  final String? role;
  final String? company;
  final String? avatarUrl;

  NetworkUser({
    required this.uid,
    required this.name,
    required this.email,
    this.role,
    this.company,
    this.avatarUrl,
  });

  factory NetworkUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NetworkUser(
      uid: d['uid'] ?? doc.id,
      name: d['name'] ?? 'Unknown',
      email: d['email'] ?? '',
      role: d['role'],
      company: d['company'],
      avatarUrl: d['avatarUrl'],
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get subtitle {
    if (role != null && company != null) return '$role at $company';
    if (role != null) return role!;
    if (company != null) return company!;
    return email;
  }

  Color get avatarColor {
    const colors = [
      Color(0xFF6C63FF),
      Color(0xFF43C59E),
      Color(0xFFFF6B6B),
      Color(0xFFFFB347),
      Color(0xFF4ECDC4),
      Color(0xFFE056A0),
    ];
    return colors[uid.hashCode.abs() % colors.length];
  }
}