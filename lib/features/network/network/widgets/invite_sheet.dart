import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/invite_service.dart';

/// Bottom sheet for inviting someone by phone number.
/// Shown when a contact search returns no results.
class InviteSheet extends StatefulWidget {
  final InviteService service;
  final String prefillPhone;

  const InviteSheet({
    super.key,
    required this.service,
    this.prefillPhone = '',
  });

  static void show(
    BuildContext context, {
    required InviteService service,
    String prefillPhone = '',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteSheet(
        service: service,
        prefillPhone: prefillPhone,
      ),
    );
  }

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  late final TextEditingController _phoneController;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController =
        TextEditingController(text: widget.prefillPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _inviterName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'Someone';

  bool _isValidPhone(String value) {
    // Accepts formats like +447911123456, 07911123456, +1234567890
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned);
  }

  Future<void> _sendInvite() async {
    final phone = _phoneController.text.trim();

    if (!_isValidPhone(phone)) {
      setState(() => _error = 'Please enter a valid phone number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.service.sendInvite(
        phone: phone,
        inviterName: _inviterName,
      );
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _sent ? _SuccessView(onDone: () => Navigator.of(context).pop()) : _FormView(
          phoneController: _phoneController,
          loading: _loading,
          error: _error,
          onSend: _sendInvite,
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Form view
// ─────────────────────────────────────────────
class _FormView extends StatelessWidget {
  final TextEditingController phoneController;
  final bool loading;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _FormView({
    required this.phoneController,
    required this.loading,
    required this.error,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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

        // Icon + title
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sms_outlined,
                  color: Color(0xFF6C63FF), size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite via SMS',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                Text("They'll get a link to join BuilderVet",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Phone input
        const Text('Phone Number',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFFF6B6B)
                  : Colors.transparent,
            ),
          ),
          child: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+44 7911 123456',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.phone_outlined,
                  color: Colors.grey[400], size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // Error message
        if (error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF6B6B), size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(error!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFFF6B6B))),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        // Helper text
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
                  'They will receive an SMS with a link to download and join BuilderVet.',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Buttons
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : onSend,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 16),
            label:
                Text(loading ? 'Sending...' : 'Send Invitation'),
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
            onPressed: onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Success view shown after invite is sent
// ─────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF43C59E).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: Color(0xFF43C59E), size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Invitation Sent!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text(
          "They'll receive an SMS with a link to join BuilderVet.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
