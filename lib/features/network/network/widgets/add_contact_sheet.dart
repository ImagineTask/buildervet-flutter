import 'package:flutter/material.dart';
import '../models/network_user.dart';
import '../services/contacts_service.dart';
import '../services/invite_service.dart';
import 'invite_sheet.dart';

/// Bottom sheet opened by the + button.
/// Allows searching users by email and adding them as a contact.
/// If no user is found, shows an option to invite via SMS.
class AddContactSheet extends StatefulWidget {
  final ContactsService service;
  final InviteService inviteService;
  final List<String> existingContactIds;

  const AddContactSheet({
    super.key,
    required this.service,
    required this.inviteService,
    required this.existingContactIds,
  });

  /// Convenience method to show the sheet from any screen.
  static void show(
    BuildContext context, {
    required ContactsService service,
    required InviteService inviteService,
    required List<String> existingContactIds,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddContactSheet(
        service: service,
        inviteService: inviteService,
        existingContactIds: existingContactIds,
      ),
    );
  }

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final TextEditingController _emailController = TextEditingController();
  List<NetworkUser> _results = [];
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _message = null;
      _results = [];
    });
    try {
      final results = await widget.service.searchByEmail(
        _emailController.text,
        widget.existingContactIds,
      );
      setState(() {
        _results = results;
        if (results.isEmpty) _message = 'No users found with that email.';
      });
    } catch (_) {
      setState(() => _message = 'Something went wrong. Try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _add(NetworkUser user) async {
    await widget.service.addContact(user.uid);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Add Contact',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 4),
            Text(
              'Search by email address',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            // Email input + search button
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Enter email address...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.email_outlined,
                            color: Colors.grey[400], size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded,
                            color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // No results — show invite option
            if (_message != null && _results.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_search_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('No account found',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This person isn\'t on BuilderVet yet. Invite them via SMS.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        InviteSheet.show(
                          context,
                          service: widget.inviteService,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sms_outlined,
                                color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Invite via SMS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Search results
            ..._results.map((user) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: user.avatarColor,
                        child: Text(user.initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A2E))),
                            Text(user.email,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _add(user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Add',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}