// lib/models/loan_detail_model.dart
import 'package:pledge_loan_mobile/models/transaction_model.dart';

// --- 1. NEW CLASS FOR THE CALCULATED STATS ---
class CalculatedStats {
  final String totalInterestOwed;
  final String principalPaid;
  final String interestPaid;
  final String totalPaid;
  final String outstandingPrincipal;
  final String outstandingInterest;
  final String amountDue;

  CalculatedStats({
    required this.totalInterestOwed,
    required this.principalPaid,
    required this.interestPaid,
    required this.totalPaid,
    required this.outstandingPrincipal,
    required this.outstandingInterest,
    required this.amountDue,
  });

  factory CalculatedStats.fromJson(Map<String, dynamic> json) {
    return CalculatedStats(
      totalInterestOwed: json['totalInterestOwed']?.toString() ?? '0.00',
      principalPaid: json['principalPaid']?.toString() ?? '0.00',
      interestPaid: json['interestPaid']?.toString() ?? '0.00',
      totalPaid: json['totalPaid']?.toString() ?? '0.00',
      outstandingPrincipal: json['outstandingPrincipal']?.toString() ?? '0.00',
      outstandingInterest: json['outstandingInterest']?.toString() ?? '0.00',
      amountDue: json['amountDue']?.toString() ?? '0.00',
    );
  }
}

class LoanDetail {
  // From 'loanDetails' object
  final int id;
  final String customerName;
  final String? phoneNumber;
  final String principalAmount;
  final String interestRate;
  final String status;
  final String pledgeDate;
  final String dueDate;
  final String? bookLoanNumber;
  final String? itemType;
  final String? description;
  final String? quality;
  final String? weight;
  final String? itemImageDataUrl;

  // From 'transactions' array
  final List<Transaction> transactions;

  // --- 2. ADD THE NEW CALCULATED OBJECT ---
  final CalculatedStats calculated;

  LoanDetail({
    required this.id,
    required this.customerName,
    this.phoneNumber,
    required this.principalAmount,
    required this.interestRate,
    required this.status,
    required this.pledgeDate,
    required this.dueDate,
    this.bookLoanNumber,
    this.itemType,
    this.description,
    this.quality,
    this.weight,
    this.itemImageDataUrl,
    required this.transactions,
    required this.calculated, // <-- Add to constructor
  });

  factory LoanDetail.fromJson(Map<String, dynamic> json) {
    final details = json['loanDetails'];
    final transactionsData = json['transactions'] as List;
    // --- 3. PARSE THE NEW OBJECT ---
    final calculatedData = json['calculated'];

    if (details == null || transactionsData == null || calculatedData == null) {
      throw Exception('Invalid loan detail data from server.');
    }

    List<Transaction> parsedTransactions = transactionsData
        .map((tx) => Transaction.fromJson(tx))
        .toList();

    return LoanDetail(
      id: details['id'],
      customerName: details['customer_name'],
      phoneNumber: details['phone_number'],
      principalAmount: details['principal_amount'].toString(),
      interestRate: details['interest_rate'].toString(),
      status: details['status'],
      pledgeDate: details['pledge_date'],
      dueDate: details['due_date'],
      bookLoanNumber: details['book_loan_number'],
      itemType: details['item_type'],
      description: details['description'],
      quality: details['quality'],
      weight: details['weight']?.toString(),
      itemImageDataUrl: details['item_image_data_url'],
      transactions: parsedTransactions,
      // --- 4. PASS THE PARSED OBJECT ---
      calculated: CalculatedStats.fromJson(calculatedData),
    );
  }
}