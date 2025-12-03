// lib/pages/reports_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pledge_loan_mobile/models/financial_report_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ApiService _apiService = ApiService();

  // State
  DateTimeRange? _selectedDateRange;
  FinancialReport? _reportData;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    _selectedDateRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    if (_selectedDateRange == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
      final endStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);

      // 1. Get stored branch
      final prefs = await SharedPreferences.getInstance();
      final branchId = prefs.getInt('current_branch_view');

      // 2. Pass to API
      final data = await _apiService.getFinancialReport(startStr, endStr, branchId: branchId);
      setState(() {
        _reportData = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchReport();
    }
  }

  // Quick Filters
  void _setMonth(int offset) {
    final now = DateTime.now();
    // Offset 0 = This Month, -1 = Last Month
    final targetMonth = DateTime(now.year, now.month + offset, 1);
    final endTarget = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    setState(() {
      _selectedDateRange = DateTimeRange(start: targetMonth, end: endTarget);
    });
    _fetchReport();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final startFmt = _selectedDateRange != null ? DateFormat('dd MMM').format(_selectedDateRange!.start) : '-';
    final endFmt = _selectedDateRange != null ? DateFormat('dd MMM yyyy').format(_selectedDateRange!.end) : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Financial Summary'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- FILTERS ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Quick Tabs
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _setMonth(-1),
                        child: const Text("Last Month"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _setMonth(0),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.indigo.withOpacity(0.1),
                          side: const BorderSide(color: Colors.indigo),
                        ),
                        child: const Text("This Month"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Custom Picker
                InkWell(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range, size: 20, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text("$startFmt - $endFmt", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- CONTENT ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _reportData == null
                ? const Center(child: Text("Select a date range"))
                : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // PROFIT CARD
                _buildSummaryCard(
                  title: "NET PROFIT",
                  value: _reportData!.netProfit,
                  color: Colors.indigo,
                  icon: Icons.auto_graph,
                  isHighlighted: true,
                ),
                const SizedBox(height: 16),

                // BREAKDOWN
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Interest Collected",
                        value: _reportData!.totalInterest,
                        color: Colors.green,
                        icon: Icons.savings,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Discounts Given",
                        value: _reportData!.totalDiscount,
                        color: Colors.orange,
                        icon: Icons.local_offer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Principal Repaid",
                        value: _reportData!.totalPrincipalRepaid,
                        color: Colors.blue,
                        icon: Icons.arrow_circle_down,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Total Disbursed",
                        value: _reportData!.totalDisbursed,
                        color: Colors.red,
                        icon: Icons.arrow_circle_up,
                        // --- NEW: Display the count here ---
                        subtitle: "${_reportData!.loansCreatedCount} New Loans",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Text(
                  "* Net Profit = Interest Collected - Discounts Given.\nPrincipal movement does not affect profit.",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    String? subtitle, // --- NEW PARAMETER ---
    bool isHighlighted = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isHighlighted ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: isHighlighted ? 32 : 24),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text("PROFIT", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                )
            ],
          ),
          SizedBox(height: isHighlighted ? 16 : 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isHighlighted ? 14 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(value),
            style: TextStyle(
              color: Colors.black87,
              fontSize: isHighlighted ? 32 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          // --- NEW: Display Subtitle if present ---
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}