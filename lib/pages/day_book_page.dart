// lib/pages/day_book_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this

class DayBookPage extends StatefulWidget {
  const DayBookPage({super.key});

  @override
  State<DayBookPage> createState() => _DayBookPageState();
}

class _DayBookPageState extends State<DayBookPage> {
  final ApiService _apiService = ApiService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _dayBookData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDayBook();
  }

  Future<void> _fetchDayBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 1. Get stored branch
      final prefs = await SharedPreferences.getInstance();
      final branchId = prefs.getInt('current_branch_view');

      // 2. Pass to API
      final data = await _apiService.getDayBook(dateStr, branchId: branchId);
      setState(() {
        _dayBookData = data;
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchDayBook();
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0';
    return '₹${double.parse(amount.toString()).toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Day Book (Chitta)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Date Selector ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: InkWell(
              onTap: () => _selectDate(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                ],
              ),
            ),
          ),

          // --- Content ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _buildLedger(),
          ),
        ],
      ),
    );
  }

  Widget _buildLedger() {
    if (_dayBookData == null) return const Center(child: Text("No data"));

    final openingBalance = double.parse(_dayBookData!['openingBalance'].toString());
    final transactions = _dayBookData!['transactions'] as List;

    // Calculate Totals
    double totalCredit = 0;
    double totalDebit = 0;

    // Process transactions to add running balance
    List<Map<String, dynamic>> processedTx = [];
    double runningBalance = openingBalance;

    for (var tx in transactions) {
      final type = tx['payment_type'];
      final amount = double.parse(tx['amount_paid'].toString());

      // Credit (IN): interest, principal, settlement
      // Debit (OUT): disbursement
      bool isCredit = ['interest', 'principal', 'settlement'].contains(type);

      if (isCredit) {
        runningBalance += amount;
        totalCredit += amount;
      } else {
        runningBalance -= amount;
        totalDebit += amount;
      }

      processedTx.add({
        ...tx,
        'isCredit': isCredit,
        'balanceAfter': runningBalance,
      });
    }

    return Column(
      children: [
        // --- SUMMARY CARDS ---
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildSummaryCard("Opening", openingBalance, Colors.orange[100]!, Colors.orange[900]!),
              const SizedBox(width: 8),
              _buildSummaryCard("Total IN", totalCredit, Colors.green[100]!, Colors.green[900]!),
              const SizedBox(width: 8),
              _buildSummaryCard("Total OUT", totalDebit, Colors.red[100]!, Colors.red[900]!),
            ],
          ),
        ),

        // --- TRANSACTION LIST ---
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text("No transactions for this date.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: processedTx.length,
            itemBuilder: (ctx, i) {
              final tx = processedTx[i];
              final isCredit = tx['isCredit'];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  title: Text(tx['customer_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text("${tx['payment_type'].toString().toUpperCase()} • #${tx['book_loan_number']}", style: const TextStyle(fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${isCredit ? '+' : '-'} ${_formatCurrency(tx['amount_paid'])}",
                        style: TextStyle(
                          color: isCredit ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "Bal: ${_formatCurrency(tx['balanceAfter'])}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // --- CLOSING BALANCE ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.indigo,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("CLOSING CASH BALANCE", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              Text(_formatCurrency(runningBalance), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color bg, Color text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: text.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_formatCurrency(amount), style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}