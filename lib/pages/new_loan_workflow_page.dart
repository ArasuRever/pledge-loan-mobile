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
      if (mounted) {
        setState(() {
          _allCustomers = customers;
          _filteredCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Header ---
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Customer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              const SizedBox(height: 4),
              const Text("Who is pledging this item?", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        // --- List ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredCustomers.isEmpty
              ? Center(child: Text(_searchController.text.isEmpty ? "No customers found." : "No match found."))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredCustomers.length,
            itemBuilder: (context, index) {
              final customer = _filteredCustomers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Text(customer.name[0], style: TextStyle(color: Colors.orange.shade900))),
                  title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(customer.phoneNumber),
                  trailing: const Icon(Icons.add_circle, color: Colors.green),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanFormPage(customerId: customer.id, customerName: customer.name))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}