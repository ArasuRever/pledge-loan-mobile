// lib/pages/customer_detail_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/customer_page_data.dart'; // Import new holder
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/loan_detail_page.dart';

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

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
  }

  // --- THIS FUNCTION IS NOW CORRECT ---
  Future<CustomerPageData> _loadPageData() async {
    try {
      // Run both API calls at the same time
      // This 'Future.wait<dynamic>' is the fix for the build error
      final results = await Future.wait<dynamic>([
        _apiService.getCustomerDetails(widget.customerId), // This is a Future
        _apiService.getCustomerLoans(widget.customerId),  // This is a Future
      ]);

      // Combine results into our holder model
      final customer = results[0] as Customer;
      final loans = results[1] as List<CustomerLoan>;

      return CustomerPageData(customer: customer, loans: loans);
    } catch (e) {
      // If either call fails, throw an error
      throw Exception('Failed to load customer data: ${e.toString()}');
    }
  }

  void _navigateToLoanDetail(int loanId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoanDetailPage(loanId: loanId),
      ),
    ).then((_) {
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
              .where((loan) => loan.status == 'active' || loan.status == 'overdue')
              .toList();
          final closedLoans = allLoans
              .where((loan) => loan.status == 'paid' || loan.status == 'forfeited')
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
                Text(customer.phoneNumber, style: Theme.of(context).textTheme.titleMedium),
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
                        fontStyle: customer.address == null ? FontStyle.italic : FontStyle.normal
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanSection(BuildContext context, String title, List<CustomerLoan> loans) {
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
                subtitle: Text('Book #: ${loan.bookLoanNumber ?? 'N/A'} - ${loan.formattedPrincipal}'),
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