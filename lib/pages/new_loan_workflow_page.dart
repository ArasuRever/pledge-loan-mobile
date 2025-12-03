// lib/pages/new_loan_workflow_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/pages/add_customer_page.dart';
import 'package:pledge_loan_mobile/pages/loan_form_page.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

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
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  Future<void> _loadCustomers() async {
    try {
      // 1. Get stored Branch ID
      final prefs = await SharedPreferences.getInstance();
      final branchId = prefs.getInt('current_branch_view');

      // 2. Pass it to API
      final customers = await _apiService.getCustomers(branchId: branchId);

      if (mounted) {
        setState(() {
          _allCustomers = customers;
          _filteredCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        return c.name.toLowerCase().contains(query) || c.phoneNumber.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Loan'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Customer to Pledge...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // 2. Create New Customer Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCustomerPage()))
                      .then((_) => _loadCustomers()); // Refresh on return
                },
                icon: const Icon(Icons.person_add),
                label: const Text("Create New Customer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),

          // 3. Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No customers found.", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Text(customer.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(customer.phoneNumber),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoanFormPage(
                          customerId: customer.id,
                          customerName: customer.name,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}