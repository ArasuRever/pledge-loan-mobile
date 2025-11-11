// lib/models/loan_model.dart
import 'package:flutter/material.dart'; // For date formatting

class Loan {
  final int id;
  final String? bookLoanNumber;
  final String principalAmount;
  final String pledgeDate;
  final String dueDate;
  final String status;
  final String customerName;
  final String? phoneNumber;

  Loan({
    required this.id,
    this.bookLoanNumber,
    required this.principalAmount,
    required this.pledgeDate,
    required this.dueDate,
    required this.status,
    required this.customerName,
    this.phoneNumber,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'],
      bookLoanNumber: json['book_loan_number'],
      principalAmount: json['principal_amount'].toString(), // Safely convert
      pledgeDate: json['pledge_date'],
      dueDate: json['due_date'],
      status: json['status'],
      customerName: json['customer_name'],
      phoneNumber: json['phone_number'],
    );
  }

  String get formattedPrincipal {
    try {
      final amount = double.parse(principalAmount);
      return '₹${amount.toStringAsFixed(0)}';
    } catch (e) {
      return '₹---';
    }
  }

  String get formattedPledgeDate {
    try {
      final date = DateTime.parse(pledgeDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }
}