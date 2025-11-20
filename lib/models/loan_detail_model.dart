// lib/models/loan_detail_model.dart
import 'package:pledge_loan_mobile/models/transaction_model.dart';

class LoanDetail {
  final int id;
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final String? address; // Added Address
  final String? customerImageUrl;
  final String? bookLoanNumber;
  final String principalAmount;
  final String interestRate;
  final String pledgeDate;
  final String dueDate;
  final String status;
  final String? itemType;
  final String? description;
  final String? quality;
  final String? weight; // Legacy weight (Gross)
  // --- NEW ITEM FIELDS ---
  final String? grossWeight;
  final String? netWeight;
  final String? purity;
  final String? appraisedValue;

  final String? itemImageDataUrl;
  final String? closedDate;
  final List<Transaction> transactions;
  final LoanCalculatedStats calculated;
  final List<InterestBreakdownItem> interestBreakdown;

  LoanDetail({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.phoneNumber,
    this.address,
    this.customerImageUrl,
    this.bookLoanNumber,
    required this.principalAmount,
    required this.interestRate,
    required this.pledgeDate,
    required this.dueDate,
    required this.status,
    this.itemType,
    this.description,
    this.quality,
    this.weight,
    // --- NEW ---
    this.grossWeight,
    this.netWeight,
    this.purity,
    this.appraisedValue,

    this.itemImageDataUrl,
    this.closedDate,
    required this.transactions,
    required this.calculated,
    required this.interestBreakdown,
  });

  factory LoanDetail.fromJson(Map<String, dynamic> json) {
    var list = json['transactions'] as List;
    List<Transaction> transactionsList =
    list.map((i) => Transaction.fromJson(i)).toList();

    var breakdownList = <InterestBreakdownItem>[];
    if (json['interestBreakdown'] != null) {
      var listBD = json['interestBreakdown'] as List;
      breakdownList = listBD.map((i) => InterestBreakdownItem.fromJson(i)).toList();
    }

    // Helper to safely convert numeric/string fields
    String? safeString(dynamic val) => val?.toString();

    return LoanDetail(
      id: json['loanDetails']['id'],
      customerId: json['loanDetails']['customer_id'],
      customerName: json['loanDetails']['customer_name'],
      phoneNumber: json['loanDetails']['phone_number'],
      address: json['loanDetails']['address'], // Added
      customerImageUrl: json['loanDetails']['customer_image_url'],
      bookLoanNumber: json['loanDetails']['book_loan_number'],
      principalAmount: safeString(json['loanDetails']['principal_amount']) ?? '0',
      interestRate: safeString(json['loanDetails']['interest_rate']) ?? '0',
      pledgeDate: json['loanDetails']['pledge_date'],
      dueDate: json['loanDetails']['due_date'],
      status: json['loanDetails']['status'],
      itemType: json['loanDetails']['item_type'],
      description: json['loanDetails']['description'],
      quality: json['loanDetails']['quality'],
      weight: safeString(json['loanDetails']['weight']),

      // --- MAP NEW FIELDS ---
      grossWeight: safeString(json['loanDetails']['gross_weight']),
      netWeight: safeString(json['loanDetails']['net_weight']),
      purity: json['loanDetails']['purity'],
      appraisedValue: safeString(json['loanDetails']['appraised_value']),

      itemImageDataUrl: json['loanDetails']['item_image_data_url'],
      closedDate: json['loanDetails']['closed_date'],
      transactions: transactionsList,
      calculated: LoanCalculatedStats.fromJson(json['calculated']),
      interestBreakdown: breakdownList,
    );
  }
}

class LoanCalculatedStats {
  final String totalInterestOwed;
  final String principalPaid;
  final String interestPaid;
  final String totalPaid;
  final String outstandingPrincipal;
  final String outstandingInterest;
  final String amountDue;

  LoanCalculatedStats({
    required this.totalInterestOwed,
    required this.principalPaid,
    required this.interestPaid,
    required this.totalPaid,
    required this.outstandingPrincipal,
    required this.outstandingInterest,
    required this.amountDue,
  });

  factory LoanCalculatedStats.fromJson(Map<String, dynamic> json) {
    return LoanCalculatedStats(
      totalInterestOwed: json['totalInterestOwed'].toString(),
      principalPaid: json['principalPaid'].toString(),
      interestPaid: json['interestPaid'].toString(),
      totalPaid: json['totalPaid'].toString(),
      outstandingPrincipal: json['outstandingPrincipal'].toString(),
      outstandingInterest: json['outstandingInterest'].toString(),
      amountDue: json['amountDue'].toString(),
    );
  }
}

class InterestBreakdownItem {
  final String label;
  final String amount;
  final String date;
  final double months;
  final String interest;

  InterestBreakdownItem({
    required this.label,
    required this.amount,
    required this.date,
    required this.months,
    required this.interest,
  });

  factory InterestBreakdownItem.fromJson(Map<String, dynamic> json) {
    return InterestBreakdownItem(
      label: json['label'],
      amount: json['amount'].toString(),
      date: json['date'],
      months: (json['months'] is int) ? (json['months'] as int).toDouble() : json['months'],
      interest: json['interest'].toString(),
    );
  }
}