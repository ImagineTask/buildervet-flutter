import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────────────
// Design tokens — matches chat_screen.dart
// ─────────────────────────────────────────────
const _bg            = Color(0xFFFAFAFC);
const _surface       = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F5F7);
const _accent        = Color(0xFF1A1A2E);
const _accentPop     = Color(0xFF4F6EF7);
const _textPrimary   = Color(0xFF0F0F1A);
const _textSecondary = Color(0xFF9899A6);
const _online        = Color(0xFF22C55E);
const _divider       = Color(0xFFF0F0F4);
const _inputBg       = Color(0xFFF4F5F7);

// ─────────────────────────────────────────────
// NewConversationPage
//
// Loads the current user's `contacts` array
// (list of UIDs), fetches each contact's user
// doc, then lets the user pick one to chat with.
// ─────────────────────────────────────────────

class NewConversationPage extends StatefulWidget {
  const NewConversationPage({super.key});

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _loadingUid;

  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Fetches the current user's contacts list then resolves each UID
  // into a full user document.
  Future<List<Map<String, dynamic>>> _loadContacts() async {
    // 1. Get the current user doc to read the contacts array
    final currentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .get();

    final contactUids = List<String>.from(
        currentDoc.data()?['contacts'] as List? ?? []);

    if (contactUids.isEmpty) return [];

    // 2. Fetch each contact's user doc (batched in groups of 10
    //    to stay within Firestore's whereIn limit)
    final List<Map<String, dynamic>> contacts = [];

    for (var i = 0; i < contactUids.length; i += 10) {
      final batch = contactUids.sublist(
          i, i + 10 > contactUids.length ? contactUids.length : i + 10);

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snap.docs) {
        contacts.add({'uid': doc.id, ...doc.data()});
      }
    }

    return contacts;
  }

  // ── Find or create 1-to-1 chat, then navigate ────────────────────

  Future<void> _openChat(Map<String, dynamic> contactData) async {
    final otherUid = contactData['uid'] as String;
    if (_loadingUid != null) return;
    setState(() => _loadingUid = otherUid);

    try {
      // Check if a chat between these two already exists
      final existing = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _currentUid)
          .get();

      String? chatId;
      for (final doc in existing.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] as List? ?? []);
        if (participants.contains(otherUid) && participants.length == 2) {
          chatId = doc.id;
          break;
        }
      }

      // Create a new chat if none exists
      if (chatId == null) {
        final currentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .get();
        final currentData = currentDoc.data() ?? {};

        // Derive initials from name if not stored
        String _initials(Map<String, dynamic> d) {
          final stored = d['initials'] as String?;
          if (stored != null && stored.isNotEmpty) return stored;
          final name = (d['name'] as String? ??
              d['company'] as String? ?? '?');
          final parts = name.trim().split(' ');
          if (parts.length >= 2) {
            return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
          }
          return name.isNotEmpty ? name[0].toUpperCase() : '?';
        }

        // Pick a deterministic colour from name if avatarColor not set
        int _color(Map<String, dynamic> d) {
          final stored = d['avatarColor'] as int?;
          if (stored != null) return stored;
          const palette = [
            0xFFFF6B6B, 0xFF43C59E, 0xFF4F6EF7,
            0xFFFFB347, 0xFF4ECDC4, 0xFFE056A0,
          ];
          final name = d['name'] as String? ?? d['company'] as String? ?? '';
          return palette[name.hashCode.abs() % palette.length];
        }

        final ref = FirebaseFirestore.instance.collection('chats').doc();
        await ref.set({
          'participants': [_currentUid, otherUid],
          'participantNames': {
            _currentUid: currentData['name'] as String? ??
                currentData['company'] as String? ?? '',
            otherUid: contactData['name'] as String? ??
                contactData['company'] as String? ?? '',
          },
          'participantInitials': {
            _currentUid: _initials(currentData),
            otherUid: _initials(contactData),
          },
          'participantColors': {
            _currentUid: _color(currentData),
            otherUid: _color(contactData),
          },
          'lastMessage': '',
          'lastMessageTime': Timestamp.now(),
          'unreadCount': {_currentUid: 0, otherUid: 0},
          'isOnline': {
            _currentUid: currentData['isOnline'] ?? false,
            otherUid: contactData['isOnline'] ?? false,
          },
        });
        chatId = ref.id;
      }

      if (!mounted) return;

      // Derive display values for ConversationScreen
      String displayName = contactData['name'] as String? ??
          contactData['company'] as String? ?? 'Unknown';

      String displayInitials(Map<String, dynamic> d) {
        final stored = d['initials'] as String?;
        if (stored != null && stored.isNotEmpty) return stored;
        final parts = displayName.trim().split(' ');
        if (parts.length >= 2) {
          return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        return displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';
      }

      const palette = [
        0xFFFF6B6B, 0xFF43C59E, 0xFF4F6EF7,
        0xFFFFB347, 0xFF4ECDC4, 0xFFE056A0,
      ];
      final colorVal = contactData['avatarColor'] as int? ??
          palette[displayName.hashCode.abs() % palette.length];

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatId: chatId!,
            currentUid: _currentUid,
            otherName: displayName,
            otherInitials: displayInitials(contactData),
            otherAvatarColor: Color(colorVal),
            isOnline: contactData['isOnline'] as bool? ?? false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open chat: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingUid = null);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 17, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Message',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _divider),
        ),
      ),
      body: Column(
        children: [
          // ── Search ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                style: const TextStyle(
                    color: _textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: const TextStyle(
                      color: _textSecondary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _textSecondary, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: _textSecondary, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // ── Section label ────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CONTACTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          // ── Contacts list ─────────────────────────────
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadContacts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _accentPop, strokeWidth: 2),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load contacts',
                        style: const TextStyle(
                            color: _textSecondary)),
                  );
                }

                final all = snapshot.data ?? [];

                // Filter by search query (name, company, or email)
                final filtered = _searchQuery.isEmpty
                    ? all
                    : all.where((c) {
                        final name =
                            (c['name'] as String? ?? '').toLowerCase();
                        final company =
                            (c['company'] as String? ?? '')
                                .toLowerCase();
                        final email =
                            (c['email'] as String? ?? '').toLowerCase();
                        return name.contains(_searchQuery) ||
                            company.contains(_searchQuery) ||
                            email.contains(_searchQuery);
                      }).toList();

                // Sort alphabetically by display name
                filtered.sort((a, b) {
                  final nameA = (a['name'] as String? ??
                      a['company'] as String? ?? '');
                  final nameB = (b['name'] as String? ??
                      b['company'] as String? ?? '');
                  return nameA
                      .toLowerCase()
                      .compareTo(nameB.toLowerCase());
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_outlined,
                            size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No contacts match "$_searchQuery"'
                              : 'No contacts yet',
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 82,
                    endIndent: 0,
                    color: _divider,
                  ),
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final uid = contact['uid'] as String;
                    final isLoading = _loadingUid == uid;

                    // Resolve display name — prefer name, fall back to company
                    final displayName = contact['name'] as String? ??
                        contact['company'] as String? ?? 'Unknown';

                    // Derive initials
                    String initials = contact['initials'] as String? ?? '';
                    if (initials.isEmpty) {
                      final parts = displayName.trim().split(' ');
                      if (parts.length >= 2) {
                        initials =
                            '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                      } else {
                        initials = displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?';
                      }
                    }

                    // Derive colour
                    const palette = [
                      0xFFFF6B6B, 0xFF43C59E, 0xFF4F6EF7,
                      0xFFFFB347, 0xFF4ECDC4, 0xFFE056A0,
                    ];
                    final colorVal = contact['avatarColor'] as int? ??
                        palette[
                            displayName.hashCode.abs() % palette.length];

                    final email = contact['email'] as String? ?? '';
                    final isOnline =
                        contact['isOnline'] as bool? ?? false;

                    return _ContactTile(
                      name: displayName,
                      subtitle: email,
                      initials: initials,
                      avatarColor: Color(colorVal),
                      isOnline: isOnline,
                      isLoading: isLoading,
                      onTap: () => _openChat(contact),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Contact Tile
// ─────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String initials;
  final Color avatarColor;
  final bool isOnline;
  final bool isLoading;
  final VoidCallback onTap;

  const _ContactTile({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.avatarColor,
    required this.isOnline,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      splashColor: _accentPop.withOpacity(0.04),
      highlightColor: _accentPop.withOpacity(0.03),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // ── Avatar ─────────────────────────────────
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: _online,
                        shape: BoxShape.circle,
                        border: Border.all(color: _bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Name + subtitle ─────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Indicator ───────────────────────────────
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: _accentPop, strokeWidth: 2),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: _textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
