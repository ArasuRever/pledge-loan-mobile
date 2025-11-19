// lib/pages/recycle_bin_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/recycle_bin_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  final ApiService _apiService = ApiService();
  RecycleBinData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = 'staff';

  @override
  void initState() {
    super.initState();
    _loadRoleAndData();
  }

  Future<void> _loadRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role') ?? 'staff';
    });
    if (_userRole == 'admin') {
      await _fetchData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.getRecycleBinData();
      setState(() {
        _data = data;
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

  Future<void> _handleAction(
      Future<Map<String, dynamic>> Function() apiCall, String successMessage) async {
    try {
      await apiCall();
      _showSnackbar(successMessage, isError: false);
      _fetchData();
    } catch (e) {
      _showSnackbar(e.toString(), isError: true);
    }
  }

  // --- NEW: Confirmation Dialog for Permanent Delete ---
  Future<bool> _showPermanentDeleteConfirmation(String itemType, String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Permanent Deletion'),
          content: Text(
            '⚠️ WARNING: Are you absolutely sure you want to PERMANENTLY DELETE this $itemType ($name) and ALL associated data? This cannot be undone.',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('DELETE FOREVER'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // --- NEW: Permanent Delete Customer Handler ---
  Future<void> _permanentDeleteCustomer(int id, String name) async {
    final confirmed = await _showPermanentDeleteConfirmation('customer', name);
    if (confirmed) {
      await _handleAction(
            () => _apiService.permanentDeleteCustomer(id),
        'Customer $name and all associated data permanently deleted.',
      );
    }
  }

  // --- NEW: Permanent Delete Loan Handler ---
  Future<void> _permanentDeleteLoan(int id, String bookNumber) async {
    final confirmed = await _showPermanentDeleteConfirmation('loan', 'Book #$bookNumber');
    if (confirmed) {
      await _handleAction(
            () => _apiService.permanentDeleteLoan(id),
        'Loan #$bookNumber permanently deleted.',
      );
    }
  }

  Future<void> _restoreCustomer(int id, String name) async {
    await _handleAction(
          () => _apiService.restoreCustomer(id),
      'Customer $name and their loans restored.',
    );
  }

  Future<void> _restoreLoan(int id, String bookNumber) async {
    await _handleAction(
          () => _apiService.restoreLoan(id),
      'Loan #$bookNumber restored.',
    );
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Recycle Bin')),
        body: const Center(child: Text("Access Denied. Admins only.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle Bin')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text("Error: $_errorMessage"))
          : RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          children: [
            _buildHeader('Deleted Customers (${_data!.customers.length})'),
            ..._data!.customers.map(_buildCustomerTile),
            _buildHeader('Deleted Loans (${_data!.loans.length})'),
            ..._data!.loans.map(_buildLoanTile),
            if (_data!.customers.isEmpty && _data!.loans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text("The recycle bin is empty.", style: TextStyle(color: Colors.grey))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildCustomerTile(CustomerItem customer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        title: Text('${customer.name} (ID: ${customer.id})'),
        subtitle: Text('Phone: ${customer.phoneNumber}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              onPressed: () => _restoreCustomer(customer.id, customer.name),
              tooltip: 'Restore Customer',
            ),
            // --- NEW BUTTON ---
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _permanentDeleteCustomer(customer.id, customer.name),
              tooltip: 'Delete Forever',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanTile(LoanItem loan) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        title: Text('Loan #${loan.bookLoanNumber} (ID: ${loan.id})'),
        subtitle: Text('Customer: ${loan.customerName}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              onPressed: () => _restoreLoan(loan.id, loan.bookLoanNumber),
              tooltip: 'Restore Loan',
            ),
            // --- NEW BUTTON ---
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _permanentDeleteLoan(loan.id, loan.bookLoanNumber),
              tooltip: 'Delete Forever',
            ),
          ],
        ),
      ),
    );
  }
}