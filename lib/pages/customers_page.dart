// lib/pages/customers_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart'; // <-- THE FIX
import 'package:pledge_loan_mobile/models/customer_model.dart'; // <-- THE FIX

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  String _statusMessage = 'Loading customers...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  Future<void> _loadCustomers() async {
    setState(() { _isLoading = true; });
    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
        _statusMessage = customers.isEmpty ? 'No customers found.' : 'Search for a customer.';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Customers',
              hintText: 'Search by name or phone number...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () { _searchController.clear(); },
              )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCustomers,
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
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tapped on ${customer.name}')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}