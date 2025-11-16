// lib/models/recycle_bin_model.dart

class RecycleBinData {
  final List<RecycleBinCustomer> customers;
  final List<RecycleBinLoan> loans;

  RecycleBinData({required this.customers, required this.loans});

  factory RecycleBinData.fromJson(Map<String, dynamic> json) {
    var customerList = json['customers'] as List;
    List<RecycleBinCustomer> customers =
    customerList.map((i) => RecycleBinCustomer.fromJson(i)).toList();

    var loanList = json['loans'] as List;
    List<RecycleBinLoan> loans =
    loanList.map((i) => RecycleBinLoan.fromJson(i)).toList();

    return RecycleBinData(
      customers: customers,
      loans: loans,
    );
  }
}

class RecycleBinCustomer {
  final int id;
  final String name;
  final String phoneNumber;

  RecycleBinCustomer(
      {required this.id, required this.name, required this.phoneNumber});

  factory RecycleBinCustomer.fromJson(Map<String, dynamic> json) {
    return RecycleBinCustomer(
      id: json['id'],
      name: json['name'] ?? 'N/A',
      phoneNumber: json['phone_number'] ?? 'N/A',
    );
  }
}

class RecycleBinLoan {
  final int id;
  final String bookLoanNumber;
  final String customerName;

  RecycleBinLoan(
      {required this.id,
        required this.bookLoanNumber,
        required this.customerName});

  factory RecycleBinLoan.fromJson(Map<String, dynamic> json) {
    return RecycleBinLoan(
      id: json['id'],
      bookLoanNumber: json['book_loan_number'] ?? 'N/A',
      customerName: json['customer_name'] ?? 'N/A',
    );
  }
}