import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _displayName {
    final name = _user?.displayName;
    if (name != null && name.isNotEmpty) return name;
    return _user?.email?.split('@').first ?? 'User';
  }

  String get _initials {
    final name = _user?.displayName ?? '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        // Pop everything off the stack — AuthGate will redirect to AuthScreen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              _Header(
                displayName: _displayName,
                email: _user?.email ?? '',
                photoURL: _user?.photoURL,
                initials: _initials,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              // ── Sections ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account
                    _SectionLabel(label: 'Account'),
                    const SizedBox(height: 10),
                    _MenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          onTap: () {
                            // TODO: Navigate to edit profile screen
                          },
                        ),
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: () {
                            // TODO: Navigate to change password screen
                          },
                        ),
                        _MenuItem(
                          icon: Icons.notifications_outlined,
                          label: 'Notifications',
                          onTap: () {
                            // TODO: Navigate to notifications settings
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // App
                    _SectionLabel(label: 'App'),
                    const SizedBox(height: 10),
                    _MenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.info_outline_rounded,
                          label: 'About',
                          onTap: () {
                            // TODO: Navigate to about screen
                          },
                        ),
                        _MenuItem(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          onTap: () {
                            // TODO: Open privacy policy
                          },
                        ),
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: 'Terms of Service',
                          onTap: () {
                            // TODO: Open terms of service
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sign out
                    _SectionLabel(label: 'Session'),
                    const SizedBox(height: 10),
                    _MenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.logout_rounded,
                          label: 'Sign Out',
                          color: const Color(0xFFFF6B6B),
                          onTap: () => _signOut(context),
                          showChevron: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // App version
                    Center(
                      child: Text(
                        'BuilderVet v1.0.0',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header with avatar + name + email
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoURL;
  final String initials;
  final VoidCallback onBack;

  const _Header({
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.initials,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF6C63FF),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Back button row
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Avatar
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withOpacity(0.25),
              backgroundImage:
                  photoURL != null ? NetworkImage(photoURL!) : null,
              child: photoURL == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[400],
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Menu card with list of items
// ─────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey[100],
                    indent: 52),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Menu item row
// ─────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1A1A2E),
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }
}