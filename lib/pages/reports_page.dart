// lib/pages/reports_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pledge_loan_mobile/models/financial_report_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ApiService _apiService = ApiService();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  FinancialReport? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Set defaults to the first and last day of the current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _fetchReport();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Format dates as YYYY-MM-DD for the API
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final data = await _apiService.getFinancialReport(startStr, endStr);
      setState(() {
        _reportData = data;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Date Filter Card ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(10),
                              ),
                              child: Text(DateFormat('dd-MMM-yyyy').format(_startDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(10),
                              ),
                              child: Text(DateFormat('dd-MMM-yyyy').format(_endDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fetchReport,
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Generate Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Error Message ---
            if (_errorMessage != null)
              Card(color: Colors.red[50], child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: Colors.red[900])))),

            // --- Report Data ---
            if (_reportData != null && !_isLoading)
              Expanded(
                child: ListView(
                  children: [
                    // Net Profit Card
                    Card(
                      color: Colors.green[50],
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.green.shade200), borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text('NET PROFIT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 8),
                            Text(_formatCurrency(_reportData!.netProfit), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[900])),
                            const SizedBox(height: 8),
                            Text('(Interest - Discounts)', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inflow Card
                    _buildDetailCard(
                      title: 'Collections (Inflow)',
                      color: Colors.blue,
                      rows: [
                        _buildRow('Interest Collected', _reportData!.totalInterest, isPositive: true),
                        _buildRow('Principal Repaid', _reportData!.totalPrincipalRepaid, isPositive: true),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Outflow Card
                    _buildDetailCard(
                      title: 'Outflow & Adjustments',
                      color: Colors.orange,
                      rows: [
                        _buildRow('New Loans / Top-ups', _reportData!.totalDisbursed, isPositive: false),
                        _buildRow('Discounts Given', _reportData!.totalDiscount, isPositive: false),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({required String title, required MaterialColor color, required List<Widget> rows}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(side: BorderSide(color: color.shade200), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color.shade900)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double amount, {required bool isPositive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            '${isPositive ? '+' : '-'} ${_formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }
}