import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SendQuotePage
//
// Builder selects a homeowner from their contacts network.
// On confirm → adds the homeowner's uid to participantIds on all tasks
// under the project, so the homeowner can see and action the quote.
// ─────────────────────────────────────────────────────────────────────────────

class SendQuotePage extends StatefulWidget {
  final String projectId;

  const SendQuotePage({super.key, required this.projectId});

  @override
  State<SendQuotePage> createState() => _SendQuotePageState();
}

class _SendQuotePageState extends State<SendQuotePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedUid;
  String? _selectedName;
  bool _sending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Fetch current user's contacts who are homeowners ──────────────────────

  Future<List<_ContactModel>> _fetchHomeowners() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    // Get current user's contacts array
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final contacts =
        List<String>.from(userDoc.data()?['contacts'] ?? []);

    if (contacts.isEmpty) return [];

    // Fetch each contact and filter by role == 'homeowner'
    final futures = contacts.map((contactUid) =>
        FirebaseFirestore.instance
            .collection('users')
            .doc(contactUid)
            .get());
    final docs = await Future.wait(futures);

    return docs
        .where((d) => d.exists)
        .map((d) => _ContactModel.fromFirestore(d))
        .where((c) => c.role.toLowerCase() == 'homeowner')
        .toList();
  }

  // ── Send quote to selected homeowner ─────────────────────────────────────

  Future<void> _send() async {
    if (_selectedUid == null) return;
    setState(() => _sending = true);

    try {
      // Get all tasks under this project
      final tasksSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('parentTaskId', isEqualTo: widget.projectId)
          .where('taskType', isEqualTo: 'task')
          .get();

      // Also add to the project task itself
      final projectSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.projectId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      // Add homeowner to all child tasks
      for (final doc in tasksSnap.docs) {
        final current =
            List<String>.from(doc.data()['participantIds'] ?? []);
        if (!current.contains(_selectedUid)) {
          current.add(_selectedUid!);
          batch.update(doc.reference, {'participantIds': current});
        }
      }

      // Add homeowner to the project task
      if (projectSnap.exists) {
        final current = List<String>.from(
            projectSnap.data()?['participantIds'] ?? []);
        if (!current.contains(_selectedUid)) {
          current.add(_selectedUid!);
          batch.update(projectSnap.reference,
              {'participantIds': current});
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Quote sent to $_selectedName'),
            backgroundColor: const Color(0xFF43C59E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Quote',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Select a homeowner',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<_ContactModel>>(
        future: _fetchHomeowners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF43C59E)),
            );
          }

          final homeowners = snapshot.data ?? [];

          if (homeowners.isEmpty) {
            return const _EmptyContacts();
          }

          // Filter by search
          final filtered = _searchQuery.isEmpty
              ? homeowners
              : homeowners
                  .where((c) => c.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
                  .toList();

          return Column(
            children: [
              // Search bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle:
                        TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.grey[400], size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.clear,
                                color: Colors.grey[400], size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const Divider(height: 1),

              // Contact list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No homeowners found.',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final contact = filtered[index];
                          final isSelected =
                              _selectedUid == contact.uid;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedUid = contact.uid;
                              _selectedName = contact.name;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF43C59E),
                                        width: 2)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF43C59E)
                                          : const Color(0xFF43C59E)
                                              .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: contact.avatarUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              contact.avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                Icons.person_outline,
                                                size: 22,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(
                                                        0xFF43C59E),
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_outline,
                                            size: 22,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF43C59E),
                                          ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name + email
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? const Color(0xFF43C59E)
                                                : const Color(0xFF1A1A2E),
                                          ),
                                        ),
                                        if (contact.email.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            contact.email,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Checkmark
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded,
                                        color: Color(0xFF43C59E), size: 22),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Send button
              if (_selectedUid != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _sending
                            ? const Color(0xFF43C59E)
                                .withValues(alpha: 0.5)
                            : const Color(0xFF43C59E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Send to $_selectedName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact Model
// ─────────────────────────────────────────────────────────────────────────────

class _ContactModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  const _ContactModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
  });

  factory _ContactModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ContactModel(
      uid: doc.id,
      name: d['name'] ?? 'Unknown',
      email: d['email'] ?? '',
      role: d['role'] ?? '',
      avatarUrl: d['avatarUrl'],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty contacts state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  size: 36, color: Color(0xFF43C59E)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No homeowners in your network',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add homeowners to your contacts to send them quotes.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
