import 'package:flutter/material.dart';
import '../base_action_tile.dart';

class ReviewQuotesAction extends BaseActionTile {
  const ReviewQuotesAction({super.key, required super.project});

  @override
  IconData get icon => Icons.request_quote_outlined;

  @override
  String get label => 'Review\nQuotes';

  @override
  Color get color => const Color(0xFF43C59E);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to quotes screen
  }
}
