// lib/pages/customer_detail_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/customer_page_data.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/loan_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/pages/loan_form_page.dart';
import 'package:pledge_loan_mobile/pages/edit_customer_page.dart'; // --- NEW IMPORT

class CustomerDetailPage extends StatefulWidget {
  final int customerId;
  final String customerName;

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
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _pageDataFuture = _loadPageData();
  }

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

  // --- FIXED: Passes correct arguments to LoanFormPage ---
  void _navigateToNewPledge(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoanFormPage(
          customerId: customer.id,       // Passing ID separately
          customerName: customer.name,   // Passing Name separately
        ),
      ),
    ).then((_) {
      // Refresh the page when we come back (to see the new loan)
      setState(() {
        _pageDataFuture = _loadPageData();
      });
    });
  }

  // --- NEW: Navigate to Edit Customer ---
  void _navigateToEditCustomer(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditCustomerPage(customer: customer),
      ),
    ).then((result) {
      // If result is true, it means the customer was updated
      if (result == true) {
        setState(() {
          _pageDataFuture = _loadPageData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer profile updated!'), backgroundColor: Colors.green),
        );
      }
    });
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
        actions: [
          // --- NEW: Edit Button ---
          FutureBuilder<CustomerPageData>(
            future: _pageDataFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: () => _navigateToEditCustomer(snapshot.data!.customer),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Existing Delete Button (Admin Only)
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Customer',
              color: Colors.red,
              onPressed: _handleDeleteCustomer,
            ),
        ],
      ),
      floatingActionButton: FutureBuilder<CustomerPageData>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return FloatingActionButton.extended(
              onPressed: () => _navigateToNewPledge(snapshot.data!.customer),
              label: const Text('New Pledge'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.green,
            );
          }
          return const SizedBox.shrink(); // Hide if data not loaded
        },
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
                  (loan) => loan.status == 'paid' || loan.status == 'forfeited' || loan.status == 'renewed')
              .toList();

          return ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.indigo.shade100,
                  backgroundImage: customer.imageUrl != null ? NetworkImage(customer.imageUrl!) : null,
                  child: customer.imageUrl == null
                      ? Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, color: Colors.indigo))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(customer.phoneNumber, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer.address ?? 'No address provided',
                    style: TextStyle(
                        fontSize: 14,
                        fontStyle: customer.address == null ? FontStyle.italic : FontStyle.normal),
                  ),
                ),
              ],
            ),
            // --- SHOW KYC DETAILS IF AVAILABLE ---
            if (customer.idProofNumber != null || customer.nomineeName != null) ...[
              const SizedBox(height: 12),
              if (customer.idProofNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(children: [
                    const Icon(Icons.badge_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text("${customer.idProofType ?? 'ID'}: ${customer.idProofNumber}", style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              if (customer.nomineeName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(children: [
                    const Icon(Icons.family_restroom, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text("Nominee: ${customer.nomineeName} (${customer.nomineeRelation ?? 'Relation'})", style: const TextStyle(fontSize: 14)),
                  ]),
                ),
            ]
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