// lib/models/customer_loan_model.dart
import 'package:flutter/material.dart';

class CustomerLoan {
  final int loanId;
  final String? bookLoanNumber;
  final String principalAmount;
  final String pledgeDate;
  final String status;
  final String? description;

  CustomerLoan({
    required this.loanId,
    this.bookLoanNumber,
    required this.principalAmount,
    required this.pledgeDate,
    required this.status,
    this.description,
  });

  factory CustomerLoan.fromJson(Map<String, dynamic> json) {
    // Matches the SELECT query in your backend
    return CustomerLoan(
      loanId: json['loan_id'],
      bookLoanNumber: json['book_loan_number'],
      principalAmount: json['principal_amount'].toString(),
      pledgeDate: json['pledge_date'],
      status: json['status'],
      description: json['description'],
    );
  }

  // Helper to format currency
  String get formattedPrincipal {
    try {
      final amount = double.parse(principalAmount);
      return '₹${amount.toStringAsFixed(0)}';
    } catch (e) {
      return '₹---';
    }
  }

  // Helper for status color
  Color get statusColor {
    switch (status) {
      case 'overdue': return Colors.red;
      case 'active': return Colors.green;
      case 'paid': return Colors.blueGrey;
      case 'forfeited': return Colors.black54;
      default: return Colors.black;
    }
  }
}