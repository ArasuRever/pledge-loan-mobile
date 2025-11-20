// lib/pages/new_loan_workflow_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'loan_form_page.dart';

class NewLoanWorkflowPage extends StatefulWidget {
  const NewLoanWorkflowPage({super.key});

  @override
  State<NewLoanWorkflowPage> createState() => _NewLoanWorkflowPageState();
}

class _NewLoanWorkflowPageState extends State<NewLoanWorkflowPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  String _statusMessage = 'Loading customers...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchController.addListener(_filterCustomers);
  }

  Future<void> _fetchCustomers() async {
    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
        _statusMessage = customers.isEmpty ? 'No customers found.' : 'Search for a customer by name or phone.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading customers: ${e.toString()}';
      });
    }
  }

  void _filterCustomers() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((customer) {
        final nameMatch = customer.name.toLowerCase().contains(searchTerm);
        final phoneMatch = customer.phoneNumber.contains(searchTerm);
        return nameMatch || phoneMatch;
      }).toList();
    });
  }

  void _onCustomerSelected(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoanFormPage(
          // --- FIX: Pass ID and Name separately ---
          customerId: customer.id,
          customerName: customer.name,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Customer',
              hintText: 'Start typing name or phone number...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text(_statusMessage),
              ],
            ))
                : _filteredCustomers.isEmpty
                ? Center(child: Text(_searchController.text.isEmpty ? _statusMessage : 'No customers match your search.'))
                : ListView.builder(
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(customer.name[0]),
                    ),
                    title: Text(customer.name),
                    subtitle: Text(customer.phoneNumber),
                    onTap: () => _onCustomerSelected(customer),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}