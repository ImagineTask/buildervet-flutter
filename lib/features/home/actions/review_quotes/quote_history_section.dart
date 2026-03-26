import 'package:flutter/material.dart';
import 'quote_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteHistorySection
//
// Displays the full project-level quote history.
// Each entry is a true snapshot written at submission time —
// total reflects the sum of ALL tasks at that point, not just one task.
// ─────────────────────────────────────────────────────────────────────────────

class QuoteHistorySection extends StatelessWidget {
  final List<QuoteHistoryEntry> history;

  const QuoteHistorySection({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Quote History',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        ...history.map((entry) => _QuoteHistoryCard(entry: entry)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuoteHistoryCard
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteHistoryCard extends StatelessWidget {
  final QuoteHistoryEntry entry;

  const _QuoteHistoryCard({required this.entry});

  IconData get _icon {
    switch (entry.type) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'declined':
        return Icons.cancel_outlined;
      default:
        return Icons.request_quote_outlined;
    }
  }

  Color get _color {
    switch (entry.type) {
      case 'approved':
        return const Color(0xFF43C59E);
      case 'declined':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  String get _label {
    switch (entry.type) {
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      default:
        return 'Quote Submitted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type + date ──────────────────────────────────────────────
          Row(
            children: [
              Icon(_icon, size: 15, color: _color),
              const SizedBox(width: 6),
              Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
              const Spacer(),
              Text(
                '${entry.submittedAt.day}/${entry.submittedAt.month}/${entry.submittedAt.year}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Actor + total ────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                entry.actorName,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const Spacer(),
              // Total is the project-level sum across all tasks
              Row(
                children: [
                  Icon(Icons.currency_pound,
                      size: 12, color: Colors.grey[400]),
                  Text(
                    entry.total.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Material + labour chips (submitted entries only) ─────────
          if (entry.type == 'submitted') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _HistoryChip(
                  label:
                      'Material: £${entry.material.toStringAsFixed(0)}',
                  icon: Icons.hardware_outlined,
                ),
                const SizedBox(width: 8),
                _HistoryChip(
                  label: 'Labour: £${entry.labour.toStringAsFixed(0)}',
                  icon: Icons.handyman_outlined,
                ),
              ],
            ),
          ],

          // ── Sent to ──────────────────────────────────────────────────
          if (entry.sentToName != null &&
              entry.sentToName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.home_outlined,
                    size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Sent to ${entry.sentToName}',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],

          // ── Note ─────────────────────────────────────────────────────
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_outlined,
                    size: 13, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.note!,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HistoryChip
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HistoryChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}