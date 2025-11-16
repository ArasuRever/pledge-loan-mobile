// lib/pages/recycle_bin_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/recycle_bin_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  late Future<RecycleBinData> _recycleBinFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _recycleBinFuture = _apiService.getRecycleBinData();
    });
  }

  Future<void> _handleRestoreCustomer(int customerId, String customerName) async {
    final confirmed = await _showConfirmationDialog(
        context, 'Restore Customer', 'Restore ${customerName}?');
    if (confirmed) {
      try {
        final message =
        await _apiService.restoreCustomer(customerId);
        _showSnackBar(message['message'] ?? 'Customer restored.', false);
        _loadData(); // Refresh the list
      } catch (e) {
        _showSnackBar('Error: ${e.toString()}', true);
      }
    }
  }

  Future<void> _handleRestoreLoan(int loanId, String bookNumber) async {
    final confirmed = await _showConfirmationDialog(
        context, 'Restore Loan', 'Restore Loan #${bookNumber}?');
    if (confirmed) {
      try {
        final message = await _apiService.restoreLoan(loanId);
        _showSnackBar(message['message'] ?? 'Loan restored.', false);
        _loadData(); // Refresh the list
      } catch (e) {
        _showSnackBar('Error: ${e.toString()}', true);
      }
    }
  }

  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<bool> _showConfirmationDialog(
      BuildContext context, String title, String content) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recycle Bin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customers', icon: Icon(Icons.people_outline)),
              // --- THIS IS THE FIX ---
              Tab(text: 'Loans', icon: Icon(Icons.article_outlined)),
              // --- END OF FIX ---
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            )
          ],
        ),
        body: FutureBuilder<RecycleBinData>(
          future: _recycleBinFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data found.'));
            }

            final customers = snapshot.data!.customers;
            final loans = snapshot.data!.loans;

            return TabBarView(
              children: [
                _buildCustomerList(customers),
                _buildLoanList(loans),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerList(List<RecycleBinCustomer> customers) {
    if (customers.isEmpty) {
      return const Center(child: Text('No deleted customers.'));
    }
    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(customer.name),
            subtitle: Text(customer.phoneNumber),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Restore', style: TextStyle(color: Colors.white)),
              onPressed: () =>
                  _handleRestoreCustomer(customer.id, customer.name),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoanList(List<RecycleBinLoan> loans) {
    if (loans.isEmpty) {
      return const Center(child: Text('No deleted loans.'));
    }
    return ListView.builder(
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text('Book #: ${loan.bookLoanNumber}'),
            subtitle: Text('Customer: ${loan.customerName}'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Restore', style: TextStyle(color: Colors.white)),
              onPressed: () => _handleRestoreLoan(loan.id, loan.bookLoanNumber),
            ),
          ),
        );
      },
    );
  }
}