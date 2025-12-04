// lib/models/loan_detail_model.dart
import 'package:pledge_loan_mobile/models/transaction_model.dart';

class LoanDetail {
  final int id;
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final String? address;
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
  final String? weight;
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
    var list = json['transactions'] as List? ?? [];
    List<Transaction> transactionsList = list.map((i) => Transaction.fromJson(i)).toList();

    var breakdownList = <InterestBreakdownItem>[];
    if (json['interestBreakdown'] != null) {
      var listBD = json['interestBreakdown'] as List;
      breakdownList = listBD.map((i) => InterestBreakdownItem.fromJson(i)).toList();
    }

    String? safeString(dynamic val) => val?.toString();

    // Access nested loanDetails safely
    final details = json['loanDetails'] ?? {};

    return LoanDetail(
      id: details['id'] ?? 0,
      customerId: details['customer_id'] ?? 0,
      customerName: details['customer_name'] ?? 'Unknown',
      phoneNumber: safeString(details['phone_number']),
      address: safeString(details['address']),
      customerImageUrl: details['customer_image_url'],
      bookLoanNumber: safeString(details['book_loan_number']),
      principalAmount: safeString(details['principal_amount']) ?? '0',
      interestRate: safeString(details['interest_rate']) ?? '0',
      pledgeDate: details['pledge_date'] ?? DateTime.now().toIso8601String(),
      dueDate: details['due_date'] ?? DateTime.now().toIso8601String(),
      status: details['status'] ?? 'active',
      itemType: details['item_type'],
      description: details['description'],
      quality: details['quality'],
      weight: safeString(details['weight']),
      grossWeight: safeString(details['gross_weight']),
      netWeight: safeString(details['net_weight']),
      purity: safeString(details['purity']),
      appraisedValue: safeString(details['appraised_value']),
      itemImageDataUrl: details['item_image_data_url'],
      closedDate: details['closed_date'],
      transactions: transactionsList,
      calculated: json['calculated'] != null
          ? LoanCalculatedStats.fromJson(json['calculated'])
          : LoanCalculatedStats.empty(),
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
      totalInterestOwed: json['totalInterestOwed']?.toString() ?? '0',
      principalPaid: json['principalPaid']?.toString() ?? '0',
      interestPaid: json['interestPaid']?.toString() ?? '0',
      totalPaid: json['totalPaid']?.toString() ?? '0',
      outstandingPrincipal: json['outstandingPrincipal']?.toString() ?? '0',
      outstandingInterest: json['outstandingInterest']?.toString() ?? '0',
      amountDue: json['amountDue']?.toString() ?? '0',
    );
  }

  factory LoanCalculatedStats.empty() {
    return LoanCalculatedStats(
      totalInterestOwed: '0', principalPaid: '0', interestPaid: '0',
      totalPaid: '0', outstandingPrincipal: '0', outstandingInterest: '0', amountDue: '0',
    );
  }
}

class InterestBreakdownItem {
  final String label;
  final String amount;
  final String date;
  final String? endDate;
  final num months; // Using num handles both int (1) and double (0.5)
  final String interest;

  InterestBreakdownItem({
    required this.label,
    required this.amount,
    required this.date,
    this.endDate,
    required this.months,
    required this.interest,
  });

  factory InterestBreakdownItem.fromJson(Map<String, dynamic> json) {
    return InterestBreakdownItem(
      label: json['label'] ?? '',
      amount: json['amount']?.toString() ?? '0',
      date: json['date'] ?? '',
      endDate: json['endDate'],
      // Safe parsing for months to prevent "double is not subtype of int" crash
      months: json['months'] is num ? json['months'] : 0,
      interest: json['interest']?.toString() ?? '0',
    );
  }
}