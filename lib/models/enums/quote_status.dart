import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum QuoteStatus {
  pending,
  accepted,
  rejected;

  String get label {
    switch (this) {
      case QuoteStatus.pending:
        return 'Pending';
      case QuoteStatus.accepted:
        return 'Accepted';
      case QuoteStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case QuoteStatus.pending:
        return AppColors.warning;
      case QuoteStatus.accepted:
        return AppColors.success;
      case QuoteStatus.rejected:
        return AppColors.error;
    }
  }

  static QuoteStatus fromString(String value) {
    return QuoteStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => QuoteStatus.pending,
    );
  }
}
