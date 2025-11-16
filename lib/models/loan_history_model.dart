// lib/models/loan_history_model.dart
import 'package:intl/intl.dart';

class LoanHistoryItem {
  final int id;
  final DateTime changedAt;
  final String? changedByUsername;
  final String eventType; // 'edit' or 'transaction'

  // Fields for 'edit'
  final String? fieldChanged;
  final String? oldValue;
  final String? newValue;

  // Fields for 'transaction'
  final String? amountPaid;
  final String? paymentType;

  LoanHistoryItem({
    required this.id,
    required this.changedAt,
    this.changedByUsername,
    required this.eventType,
    this.fieldChanged,
    this.oldValue,
    this.newValue,
    this.amountPaid,
    this.paymentType,
  });

  factory LoanHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoanHistoryItem(
      id: json['id'] ?? 0, // Use 0 as fallback ID
      changedAt: json['changed_at'] != null
          ? DateTime.parse(json['changed_at'])
          : DateTime.now(),
      changedByUsername: json['changed_by_username'] ?? 'system',
      eventType: json['event_type'],
      fieldChanged: json['field_changed'],
      oldValue: json['old_value'],
      newValue: json['new_value'],
      amountPaid: json['amount_paid']?.toString(),
      paymentType: json['payment_type'],
    );
  }

  String get formattedTimestamp {
    return DateFormat('dd-MMM-yyyy hh:mm a').format(changedAt.toLocal());
  }

  String get formattedAmount {
    if (amountPaid == null) return '₹0';
    try {
      final amount = double.parse(amountPaid!);
      return '₹${amount.toStringAsFixed(0)}';
    } catch (e) {
      return '₹---';
    }
  }
}