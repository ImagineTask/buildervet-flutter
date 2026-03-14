import 'package:flutter/material.dart';
import '../base_action_tile.dart';

class RequestQuoteAction extends BaseActionTile {
  const RequestQuoteAction({super.key, required super.project});

  @override
  IconData get icon => Icons.send_outlined;

  @override
  String get label => 'Request\nQuote';

  @override
  Color get color => const Color(0xFF43C59E);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to request quote screen
  }
}
