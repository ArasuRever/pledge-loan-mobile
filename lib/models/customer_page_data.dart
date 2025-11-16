// lib/models/customer_page_data.dart
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';

class CustomerPageData {
  final Customer customer;
  final List<CustomerLoan> loans;

  CustomerPageData({
    required this.customer,
    required this.loans,
  });
}