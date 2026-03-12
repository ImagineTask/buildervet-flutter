import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/invite_service.dart';

/// Bottom sheet for inviting someone via a shareable link.
/// Uses share_plus to open the native share sheet.
class InviteSheet extends StatefulWidget {
  final InviteService service;

  const InviteSheet({
    super.key,
    required this.service,
  });

  static void show(
    BuildContext context, {
    required InviteService service,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteSheet(service: service),
    );
  }

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  bool _loading = true;
  String? _inviteLink;
  String? _error;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _generateLink();
  }

  Future<void> _generateLink() async {
    try {
      final link = await widget.service.createInvite();
      setState(() {
        _inviteLink = link;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate invite link. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _shareLink() async {
    if (_inviteLink == null) return;
    await Share.share(
      'Join me on BuilderVet — the app for managing home renovation projects.\n\n'
      'Sign up here: $_inviteLink',
      subject: 'You\'re invited to BuilderVet',
    );
  }

  Future<void> _copyLink() async {
    if (_inviteLink == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteLink!));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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

          // Title
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.link_rounded,
                    color: Color(0xFF6C63FF), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite via Link',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                  Text('Share with anyone via any app',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 12),
                  Text('Generating your invite link...',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF6B6B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFFF6B6B))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _generateLink();
                },
                child: const Text('Try Again'),
              ),
            ),
          ] else ...[
            // Link preview box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 16, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inviteLink!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _copyLink,
                    child: Icon(
                      _copied
                          ? Icons.check_circle_rounded
                          : Icons.copy_rounded,
                      size: 18,
                      color: _copied
                          ? const Color(0xFF43C59E)
                          : const Color(0xFF6C63FF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This link is unique to you. Share it via WhatsApp, iMessage, email — any app.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _shareLink,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share Invite Link'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
