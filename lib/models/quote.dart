import 'enums/quote_status.dart';

class Quote {
  final String contractorId;
  final String contractorName;
  final double amount;
  final String description;
  final DateTime submittedAt;
  final QuoteStatus status;

  const Quote({
    required this.contractorId,
    required this.contractorName,
    required this.amount,
    required this.description,
    required this.submittedAt,
    required this.status,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      contractorId: json['contractorId'] as String,
      contractorName: json['contractorName'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      status: QuoteStatus.fromString(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contractorId': contractorId,
      'contractorName': contractorName,
      'amount': amount,
      'description': description,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.name,
    };
  }
}
