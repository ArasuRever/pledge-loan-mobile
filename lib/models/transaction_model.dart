// lib/models/transaction_model.dart
import 'package:flutter/material.dart';

class Transaction {
  final int id;
  final String amountPaid;
  final String paymentType;
  final String paymentDate;
  final String? details;

  Transaction({
    required this.id,
    required this.amountPaid,
    required this.paymentType,
    required this.paymentDate,
    this.details,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amountPaid: json['amount_paid'].toString(),
      paymentType: json['payment_type'],
      paymentDate: json['payment_date'],
      details: json['details'],
    );
  }

  // Helper to format currency
  String get formattedAmount {
    try {
      final amount = double.parse(amountPaid);
      return '₹${amount.toStringAsFixed(0)}';
    } catch (e) {
      return '₹---';
    }
  }

  // Helper to format date
  String get formattedDate {
    try {
      final date = DateTime.parse(paymentDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Helper for color and icon
  IconData get icon {
    switch (paymentType) {
      case 'interest':
        return Icons.percent;
      case 'principal':
        return Icons.attach_money;
      case 'disbursement':
        return Icons.arrow_upward;
      default:
        return Icons.payment;
    }
  }

  Color get color {
    switch (paymentType) {
      case 'interest':
        return Colors.blue;
      case 'principal':
        return Colors.green;
      case 'disbursement':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}