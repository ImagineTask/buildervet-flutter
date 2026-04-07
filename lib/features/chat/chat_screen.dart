import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'image_annotator_page.dart';
import 'new_conversation_page.dart';

// ─────────────────────────────────────────────
// Design tokens — light & clean minimal
// ─────────────────────────────────────────────
const _bg            = Color(0xFFFAFAFC);
const _surface       = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F5F7);
const _accent        = Color(0xFF1A1A2E);   // near-black accent
const _accentPop     = Color(0xFF4F6EF7);   // indigo pop for badges/bubbles
const _textPrimary   = Color(0xFF0F0F1A);
const _textSecondary = Color(0xFF9899A6);
const _online        = Color(0xFF22C55E);
const _divider       = Color(0xFFF0F0F4);
const _inputBg       = Color(0xFFF4F5F7);

// ─────────────────────────────────────────────
// Firestore schema (for reference)
//
// chats/{chatId}
//   participants: [uid1, uid2]
//   participantNames: { uid: 'Name' }
//   participantInitials: { uid: 'AB' }
//   participantColors: { uid: 0xFF... }
//   lastMessage: String
//   lastMessageTime: Timestamp
//   unreadCount: { uid: 0 }
//   isOnline: { uid: bool }
//
// chats/{chatId}/messages/{msgId}
//   senderId: uid
//   text: String
//   timestamp: Timestamp
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// ChatScreen
// ─────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          'Messages',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                            letterSpacing: -1.0,
                            height: 1.0,
                          ),
                        ),
                      ),
                      // Compose icon button
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NewConversationPage(),
                          ),
                        ),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── Search ──────────────────────────────
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _inputBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                      decoration: InputDecoration(
                        hintText: 'Search...',
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
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Chat list ─────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: _uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: _accentPop, strokeWidth: 2),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Something went wrong',
                          style: TextStyle(color: _textSecondary)),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Sort by lastMessageTime descending in client
                  // (avoids needing a Firestore composite index)
                  docs.sort((a, b) {
                    final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                    final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  final filtered = docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final names = Map<String, dynamic>.from(
                        data['participantNames'] as Map? ?? {});
                    final otherUid =
                        (data['participants'] as List).firstWhere(
                      (p) => p != _uid,
                      orElse: () => '',
                    );
                    final name = (names[otherUid] as String? ?? '')
                        .toLowerCase();
                    final lastMsg =
                        (data['lastMessage'] as String? ?? '')
                            .toLowerCase();
                    return name.contains(_searchQuery) ||
                        lastMsg.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No results found'
                                : 'No conversations yet',
                            style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index].data()
                          as Map<String, dynamic>;
                      final chatId = filtered[index].id;

                      final names = Map<String, dynamic>.from(
                          data['participantNames'] as Map? ?? {});
                      final initials = Map<String, dynamic>.from(
                          data['participantInitials'] as Map? ?? {});
                      final colors = Map<String, dynamic>.from(
                          data['participantColors'] as Map? ?? {});
                      final unread = Map<String, dynamic>.from(
                          data['unreadCount'] as Map? ?? {});
                      final online = Map<String, dynamic>.from(
                          data['isOnline'] as Map? ?? {});

                      final otherUid =
                          (data['participants'] as List).firstWhere(
                        (p) => p != _uid,
                        orElse: () => '',
                      );

                      final name =
                          names[otherUid] as String? ?? 'Unknown';
                      final initial =
                          initials[otherUid] as String? ?? '?';
                      final colorVal =
                          colors[otherUid] as int? ?? 0xFF4F6EF7;
                      final unreadCount =
                          (unread[_uid] as num?)?.toInt() ?? 0;
                      final isOnline =
                          online[otherUid] as bool? ?? false;
                      final lastMsg =
                          data['lastMessage'] as String? ?? '';
                      final lastTime =
                          data['lastMessageTime'] as Timestamp?;

                      return _ChatTile(
                        chatId: chatId,
                        currentUid: _uid,
                        name: name,
                        initials: initial,
                        avatarColor: Color(colorVal),
                        lastMessage: lastMsg,
                        timestamp: lastTime,
                        unreadCount: unreadCount,
                        isOnline: isOnline,
                        isLast: index == filtered.length - 1,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Chat Tile
// ─────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final String chatId;
  final String currentUid;
  final String name;
  final String initials;
  final Color avatarColor;
  final String lastMessage;
  final Timestamp? timestamp;
  final int unreadCount;
  final bool isOnline;
  final bool isLast;

  const _ChatTile({
    required this.chatId,
    required this.currentUid,
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
    required this.isLast,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatId: chatId,
            currentUid: currentUid,
            otherName: name,
            otherInitials: initials,
            otherAvatarColor: avatarColor,
            isOnline: isOnline,
          ),
        ),
      ),
      splashColor: _accentPop.withOpacity(0.04),
      highlightColor: _accentPop.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            // ── Avatar ───────────────────────────────────
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
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
                        border:
                            Border.all(color: _bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Name + preview ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? _textPrimary.withOpacity(0.65)
                          : _textSecondary,
                      fontWeight: hasUnread
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Time + badge ──────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        hasUnread ? _accentPop : _textSecondary,
                    fontWeight: hasUnread
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 5),
                if (hasUnread)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _accentPop,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ConversationScreen
// ─────────────────────────────────────────────

class ConversationScreen extends StatefulWidget {
  final String chatId;
  final String currentUid;
  final String otherName;
  final String otherInitials;
  final Color otherAvatarColor;
  final bool isOnline;

  const ConversationScreen({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.otherName,
    required this.otherInitials,
    required this.otherAvatarColor,
    required this.isOnline,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _sending = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'unreadCount.${widget.currentUid}': 0});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      final now = Timestamp.now();

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherUid = participants.firstWhere(
        (p) => p != widget.currentUid,
        orElse: () => '',
      );

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUid,
        'text': text,
        'timestamp': now,
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': text,
        'lastMessageTime': now,
        if (otherUid.isNotEmpty)
          'unreadCount.$otherUid': FieldValue.increment(1),
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Image source picker ──────────────────────────────────────────

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accentPop.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: _accentPop, size: 20),
                ),
                title: const Text('Take a photo',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _sendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accentPop.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: _accentPop, size: 20),
                ),
                title: const Text('Choose from gallery',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _sendImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ── Upload & send image ──────────────────────────────────────────

  Future<void> _sendImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (picked == null) return;

    // ── Annotate ─────────────────────────────────────────────────
    // Opens the draw/line/curve editor. Returns PNG bytes or null.
    final annotated = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageAnnotatorPage(imageFile: File(picked.path)),
      ),
    );
    // User tapped close without sending
    if (annotated == null) return;

    setState(() => _uploadingImage = true);

    try {
      final now = Timestamp.now();
      final fileName =
          '${widget.chatId}_${widget.currentUid}_${now.millisecondsSinceEpoch}.png';

      // Upload annotated PNG bytes to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chats/${widget.chatId}/$fileName');
      await storageRef.putData(
        annotated,
        SettableMetadata(contentType: 'image/png'),
      );
      final imageUrl = await storageRef.getDownloadURL();

      // Get other participant
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherUid = participants.firstWhere(
        (p) => p != widget.currentUid,
        orElse: () => '',
      );

      // Save message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUid,
        'text': '',
        'imageUrl': imageUrl,
        'timestamp': now,
        'type': 'image',
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': '📷 Photo',
        'lastMessageTime': now,
        if (otherUid.isNotEmpty)
          'unreadCount.$otherUid': FieldValue.increment(1),
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send image: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        elevation: 0,
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 17, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.otherAvatarColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.otherInitials,
                      style: TextStyle(
                        color: widget.otherAvatarColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (widget.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _online,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  widget.isOnline ? 'Active now' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isOnline
                        ? _online
                        : _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _divider),
        ),
      ),
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _accentPop, strokeWidth: 2),
                  );
                }

                if (snapshot.hasError) {
                  final err = snapshot.error.toString();
                  final isIndexError = err.contains('index') ||
                      err.contains('FAILED_PRECONDITION');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIndexError
                                ? Icons.data_usage_outlined
                                : Icons.error_outline_rounded,
                            size: 40,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isIndexError
                                ? 'Firestore index required'
                                : 'Failed to load messages',
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isIndexError
                                ? 'Open your Flutter debug console — Firestore will print a link to create the missing index. Tap it and deploy.'
                                : err,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _surfaceSubtle,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: const Icon(
                              Icons.waving_hand_outlined,
                              color: _textSecondary,
                              size: 24),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Say something 👋',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data()
                        as Map<String, dynamic>;
                    final isMe =
                        data['senderId'] == widget.currentUid;
                    final text = data['text'] as String? ?? '';
                    final imageUrl = data['imageUrl'] as String?;
                    final ts = data['timestamp'] as Timestamp?;

                    final showDate = index == 0 ||
                        _isDifferentDay(
                          (docs[index - 1].data()
                                  as Map<String, dynamic>)['timestamp']
                              as Timestamp?,
                          ts,
                        );

                    final prevSender = index > 0
                        ? (docs[index - 1].data()
                                as Map<String, dynamic>)['senderId']
                            as String?
                        : null;
                    final nextSender = index < docs.length - 1
                        ? (docs[index + 1].data()
                                as Map<String, dynamic>)['senderId']
                            as String?
                        : null;

                    final isFirst =
                        prevSender != data['senderId'] || showDate;
                    // Last in group = next message is from someone else
                    // or this is the last message overall
                    final isLast = nextSender != data['senderId'];

                    return Column(
                      children: [
                        if (showDate && ts != null)
                          _DateDivider(timestamp: ts),
                        _MessageBubble(
                          text: text,
                          imageUrl: imageUrl,
                          isMe: isMe,
                          timestamp: ts,
                          isFirst: isFirst,
                          isLast: isLast,
                          otherName: widget.otherName,
                          otherInitials: widget.otherInitials,
                          otherAvatarColor: widget.otherAvatarColor,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _divider)),
            ),
            padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).padding.bottom + 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upload progress indicator
                if (_uploadingImage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: _accentPop, strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('Sending photo...',
                            style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary)),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── Image picker button ─────────────────
                    GestureDetector(
                      onTap: _uploadingImage
                          ? null
                          : _showImageSourceSheet,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _inputBg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: _uploadingImage
                              ? _textSecondary.withOpacity(0.4)
                              : _textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ── Text field ──────────────────────────
                    Expanded(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: _inputBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          textCapitalization:
                              TextCapitalization.sentences,
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(
                                color: _textSecondary, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ── Send button ─────────────────────────
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year ||
        da.month != db.month ||
        da.day != db.day;
  }
}

// ─────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isMe;
  final Timestamp? timestamp;
  final bool isFirst;
  final bool isLast;
  final String otherName;
  final String otherInitials;
  final Color otherAvatarColor;

  const _MessageBubble({
    required this.text,
    required this.imageUrl,
    required this.isMe,
    required this.timestamp,
    required this.isFirst,
    required this.isLast,
    required this.otherName,
    required this.otherInitials,
    required this.otherAvatarColor,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 30.0;
    const double avatarGap = 8.0;
    final bool isImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 6 : 2,
        top: isFirst ? 10 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // ── Avatar column (other user only) ──────────
          if (!isMe) ...[
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: isLast
                  ? Container(
                      decoration: BoxDecoration(
                        color: otherAvatarColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          otherInitials,
                          style: TextStyle(
                            color: otherAvatarColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: avatarGap),
          ],

          // ── Bubble + name ─────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width *
                  (isMe ? 0.68 : 0.62),
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Name label — only on the first bubble of a group
                if (!isMe && isFirst) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      otherName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: otherAvatarColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],

                // ── Image bubble ──────────────────────────
                if (isImage)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _FullScreenImage(imageUrl: imageUrl!),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(
                            isMe ? 18 : (isLast ? 4 : 18)),
                        bottomRight: Radius.circular(
                            isMe ? (isLast ? 4 : 18) : 18),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Image.network(
                            imageUrl!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 220,
                                height: 220,
                                color: _surfaceSubtle,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: _accentPop,
                                      strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 60,
                              color: _surfaceSubtle,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: _textSecondary),
                              ),
                            ),
                          ),
                          // Timestamp overlay
                          Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatTime(timestamp),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )

                // ── Text bubble ───────────────────────────
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? _accent : _surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(
                            isMe ? 18 : (isLast ? 4 : 18)),
                        bottomRight: Radius.circular(
                            isMe ? (isLast ? 4 : 18) : 18),
                      ),
                      boxShadow: isMe
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : _textPrimary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withOpacity(0.5)
                                : _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Date Divider
// ─────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final Timestamp timestamp;
  const _DateDivider({required this.timestamp});

  String _label() {
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: Colors.grey.shade200, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(),
              style: const TextStyle(
                fontSize: 11,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
              child: Divider(
                  color: Colors.grey.shade200, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Full Screen Image Viewer
// ─────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}