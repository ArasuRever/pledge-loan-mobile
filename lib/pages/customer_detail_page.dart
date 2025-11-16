// lib/pages/customer_detail_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/customer_page_data.dart'; // Import new holder
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/loan_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart'; // --- NEW IMPORT ---

class CustomerDetailPage extends StatefulWidget {
  final int customerId;
  final String customerName; // Passed in for the AppBar title

  const CustomerDetailPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Future<CustomerPageData> _pageDataFuture;
  final ApiService _apiService = ApiService();
  String? _userRole; // --- NEW STATE FOR ROLE ---

  @override
  void initState() {
    super.initState();
    _loadUserRole(); // --- NEW: Load role ---
    _pageDataFuture = _loadPageData();
  }

  // --- NEW: Function to load user role ---
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role');
      });
    }
  }

  Future<CustomerPageData> _loadPageData() async {
    try {
      final results = await Future.wait<dynamic>([
        _apiService.getCustomerDetails(widget.customerId),
        _apiService.getCustomerLoans(widget.customerId),
      ]);

      final customer = results[0] as Customer;
      final loans = results[1] as List<CustomerLoan>;

      return CustomerPageData(customer: customer, loans: loans);
    } catch (e) {
      throw Exception('Failed to load customer data: ${e.toString()}');
    }
  }

  // --- NEW: Handle Delete Customer ---
  Future<void> _handleDeleteCustomer() async {
    final confirmed = await _showConfirmationDialog(
        context,
        'Delete Customer?',
        'Are you sure you want to move this customer to the recycle bin?');
    if (confirmed) {
      try {
        final result = await _apiService.softDeleteCustomer(widget.customerId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Customer moved to recycle bin.'),
          backgroundColor: Colors.green,
        ));
        // Pop back to customer list, returning 'true' to signal a refresh
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // --- NEW: Confirmation Dialog Helper ---
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
            child: const Text('DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    )) ??
        false;
  }

  void _navigateToLoanDetail(int loanId) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => LoanDetailPage(loanId: loanId),
      ),
    )
        .then((_) {
      // Refresh when coming back from the loan detail page
      setState(() {
        _pageDataFuture = _loadPageData();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        // --- NEW: Add Delete Button for Admin ---
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Customer',
              color: Colors.red,
              onPressed: _handleDeleteCustomer,
            ),
        ],
      ),
      body: FutureBuilder<CustomerPageData>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('This customer has no data.'));
          }

          final customer = snapshot.data!.customer;
          final allLoans = snapshot.data!.loans;

          final activeLoans = allLoans
              .where(
                  (loan) => loan.status == 'active' || loan.status == 'overdue')
              .toList();
          final closedLoans = allLoans
              .where(
                  (loan) => loan.status == 'paid' || loan.status == 'forfeited')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildCustomerDetailsCard(context, customer),
              const SizedBox(height: 24),
              _buildLoanSection(context, 'Active Loans', activeLoans),
              const SizedBox(height: 24),
              _buildLoanSection(context, 'Closed Loans', closedLoans),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomerDetailsCard(BuildContext context, Customer customer) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(customer.phoneNumber,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer.address ?? 'No address provided',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: customer.address == null
                            ? FontStyle.italic
                            : FontStyle.normal),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanSection(
      BuildContext context, String title, List<CustomerLoan> loans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Divider(),
        if (loans.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No loans in this category.'),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return Card(
              child: ListTile(
                title: Text(loan.description ?? 'Loan #${loan.loanId}'),
                subtitle: Text(
                    'Book #: ${loan.bookLoanNumber ?? 'N/A'} - ${loan.formattedPrincipal}'),
                trailing: Text(
                  loan.status.toUpperCase(),
                  style: TextStyle(
                    color: loan.statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _navigateToLoanDetail(loan.loanId),
              ),
            );
          },
        ),
      ],
    );
  }
}