// lib/models/loan_history_model.dart
import 'package:intl/intl.dart';

class LoanHistoryItem {
  final int? id;
  final int loanId;
  final String fieldChanged;
  final String? oldValue;
  final String? newValue;
  final DateTime changedAt;
  final String? changedByUsername;

  LoanHistoryItem({
    this.id,
    required this.loanId,
    required this.fieldChanged,
    this.oldValue,
    this.newValue,
    required this.changedAt,
    this.changedByUsername,
  });

  factory LoanHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoanHistoryItem(
      id: json['id'], // This is nullable (int?), so it's OK

      // --- FIX 1: Provide a default value (0) if 'loan_id' is null ---
      loanId: json['loan_id'] ?? 0,

      fieldChanged: json['field_changed'] ?? 'N/A',
      oldValue: json['old_value'],
      newValue: json['new_value'],

      // --- FIX 2: Safely parse the date, with a fallback ---
      changedAt: json['changed_at'] != null
          ? DateTime.parse(json['changed_at'])
          : DateTime.now(), // Use current time as a fallback

      changedByUsername: json['changed_by_username'] ?? 'Unknown',
    );
  }

  String get formattedTimestamp {
    // Format the date in a readable way, e.g., "16-Nov-2025 05:30 PM"
    return DateFormat('dd-MMM-yyyy hh:mm a').format(changedAt.toLocal());
  }
}