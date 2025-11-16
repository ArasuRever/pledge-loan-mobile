// lib/pages/customers_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
// TODO: We will create this page in Step 3
// import 'package:pledge_loan_mobile/pages/customer_detail_page.dart';

class CustomersPage extends StatefulWidget {
  // Add the key parameter
  const CustomersPage({super.key});

  @override
  // 1. Make the State public so MainScaffold can access it
  CustomersPageState createState() => CustomersPageState();
}

// 2. Make State class public
class CustomersPageState extends State<CustomersPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  // 3. Use a FutureBuilder pattern, just like AllLoansPage
  late Future<List<Customer>> _customersFuture;
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _customersFuture = _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  Future<List<Customer>> _loadCustomers() async {
    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
      });
      return customers;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 4. Create a public refresh method
  void handleRefresh() {
    final future = _loadCustomers();
    setState(() {
      _customersFuture = future;
      _searchController.clear();
    });
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
          // 5. Use a FutureBuilder for the list
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _customersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (_allCustomers.isEmpty) {
                  return const Center(child: Text('No customers found.'));
                }

                return RefreshIndicator(
                  onRefresh: () async => handleRefresh(),
                  child: _filteredCustomers.isEmpty
                      ? const Center(child: Text('No customers match your search.'))
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
                            // TODO: Navigate to customer detail page
                            // Navigator.of(context).push(
                            //   MaterialPageRoute(
                            //     builder: (context) => CustomerDetailPage(customerId: customer.id),
                            //   ),
                            // );
                          },
                        ),
                      );
                    },
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