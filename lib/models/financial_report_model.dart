// lib/models/financial_report_model.dart

class FinancialReport {
  final double totalDisbursed;
  final double totalInterest;
  final double totalPrincipalRepaid;
  final double totalDiscount;
  final double netProfit;
  final String startDate;
  final String endDate;

  FinancialReport({
    required this.totalDisbursed,
    required this.totalInterest,
    required this.totalPrincipalRepaid,
    required this.totalDiscount,
    required this.netProfit,
    required this.startDate,
    required this.endDate,
  });

  factory FinancialReport.fromJson(Map<String, dynamic> json) {
    return FinancialReport(
      totalDisbursed: double.parse(json['totalDisbursed'].toString()),
      totalInterest: double.parse(json['totalInterest'].toString()),
      totalPrincipalRepaid: double.parse(json['totalPrincipalRepaid'].toString()),
      totalDiscount: double.parse(json['totalDiscount'].toString()),
      netProfit: double.parse(json['netProfit'].toString()),
      startDate: json['startDate'],
      endDate: json['endDate'],
    );
  }
}