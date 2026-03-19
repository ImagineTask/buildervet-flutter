import 'package:flutter/material.dart';
import 'quote_models.dart';
import 'quote_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteDetailPage
//
// Shows the per-task breakdown of the overall project quote.
// ─────────────────────────────────────────────────────────────────────────────

class QuoteDetailPage extends StatelessWidget {
  final List<TaskItem> tasks;
  final ProjectQuote quote;
  final String role;
  final String projectId;

  const QuoteDetailPage({
    super.key,
    required this.tasks,
    required this.quote,
    required this.role,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final quotedTasks = tasks.where((t) => t.hasQuote).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          quote.builderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF43C59E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43C59E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 22, color: Color(0xFF43C59E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.builderName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${quote.submittedAt.day}/${quote.submittedAt.month}/${quote.submittedAt.year}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _DetailAmountRow(
                        label: 'Quote', amount: quote.total,
                        color: const Color(0xFF1A1A2E), fontSize: 18),
                    const SizedBox(height: 4),
                    _DetailAmountRow(
                        label: 'Agreed', amount: quote.agreedTotal,
                        color: const Color(0xFF43C59E), fontSize: 18),
                    const SizedBox(height: 6),
                    QuoteStatusBadge(status: quote.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Task breakdown card ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    'Task Breakdown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Task rows
                ...quotedTasks.asMap().entries.map((entry) {
                  final i = entry.key;
                  final task = entry.value;
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(
                            height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task name
                            Text(
                              task.taskName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Material row
                            _BreakdownRow(
                              label: 'Material',
                              icon: Icons.hardware_outlined,
                              amount: task.quoteMaterial ?? 0,
                            ),
                            const SizedBox(height: 4),
                            // Labour row
                            _BreakdownRow(
                              label: 'Labour',
                              icon: Icons.handyman_outlined,
                              amount: task.quoteLabour ?? 0,
                            ),
                            const SizedBox(height: 8),
                            // Task total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Subtotal: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500]),
                                ),
                                Icon(Icons.currency_pound,
                                    size: 11,
                                    color: Colors.grey[500]),
                                Text(
                                  task.quoteTotal.toStringAsFixed(0),
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
                      ),
                    ],
                  );
                }),

                // Grand total row
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.currency_pound,
                              size: 13, color: Colors.grey[400]),
                          Text(
                            quote.total.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF43C59E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}


class _DetailAmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final double fontSize;

  const _DetailAmountRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: TextStyle(fontSize: fontSize - 4, color: Colors.grey[500])),
        Icon(Icons.currency_pound, size: fontSize - 6, color: color),
        Text(
          amount.toStringAsFixed(0),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double amount;

  const _BreakdownRow({
    required this.label,
    required this.icon,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        Row(
          children: [
            Icon(Icons.currency_pound, size: 11, color: Colors.grey[400]),
            Text(
              amount.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}