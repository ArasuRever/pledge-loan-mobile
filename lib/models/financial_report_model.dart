// lib/models/financial_report_model.dart
class FinancialReport {
  final String startDate;
  final String endDate;
  final double totalDisbursed;
  final double totalInterest;
  final double totalPrincipalRepaid;
  final double totalDiscount;
  final double netProfit;
  final int loansCreatedCount; // --- NEW ---

  FinancialReport({
    required this.startDate,
    required this.endDate,
    required this.totalDisbursed,
    required this.totalInterest,
    required this.totalPrincipalRepaid,
    required this.totalDiscount,
    required this.netProfit,
    required this.loansCreatedCount, // --- NEW ---
  });

  factory FinancialReport.fromJson(Map<String, dynamic> json) {
    return FinancialReport(
      startDate: json['startDate'],
      endDate: json['endDate'],
      totalDisbursed: double.parse(json['totalDisbursed'].toString()),
      totalInterest: double.parse(json['totalInterest'].toString()),
      totalPrincipalRepaid: double.parse(json['totalPrincipalRepaid'].toString()),
      totalDiscount: double.parse(json['totalDiscount'].toString()),
      netProfit: double.parse(json['netProfit'].toString()),
      loansCreatedCount: int.parse((json['loansCreatedCount'] ?? 0).toString()), // --- NEW ---
    );
  }
}