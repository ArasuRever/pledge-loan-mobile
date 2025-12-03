// lib/pages/customers_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/pages/customer_detail_page.dart';
import 'package:pledge_loan_mobile/pages/loan_form_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this
import 'dart:convert';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  CustomersPageState createState() => CustomersPageState();
}

class CustomersPageState extends State<CustomersPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Customer>> _customersFuture;
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];

  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _customersFuture = _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  Future<List<Customer>> _loadCustomers() async {
    try {
      // 1. Get stored branch
      final prefs = await SharedPreferences.getInstance();
      final branchId = prefs.getInt('current_branch_view');

      // 2. Pass to API
      final customers = await _apiService.getCustomers(branchId: branchId);

      if (mounted) {
        setState(() {
          _allCustomers = customers;
          _filteredCustomers = customers;
        });
      }
      return customers;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not dial: $e')));
    }
  }

  void _showContextMenu(BuildContext context, Customer customer) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        _tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'call',
          child: Row(children: [Icon(Icons.call, color: Colors.green[700]), const SizedBox(width: 10), const Text("Call Customer")]),
        ),
        PopupMenuItem(
          value: 'pledge',
          child: Row(children: [Icon(Icons.add_circle, color: Colors.orange[700]), const SizedBox(width: 10), const Text("New Pledge")]),
        ),
        PopupMenuItem(
          value: 'view',
          child: Row(children: [Icon(Icons.visibility, color: Colors.blue[700]), const SizedBox(width: 10), const Text("View Details")]),
        ),
      ],
    );

    if (!mounted) return;

    if (result == 'call') _makePhoneCall(customer.phoneNumber);
    if (result == 'pledge') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => LoanFormPage(customerId: customer.id, customerName: customer.name)));
    }
    if (result == 'view') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailPage(customerId: customer.id, customerName: customer.name)));
    }
  }

  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Name or Phone',
              prefixIcon: const Icon(Icons.search, color: Colors.indigo),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            ),
          ),
        ),

        // List
        Expanded(
          child: FutureBuilder<List<Customer>>(
            future: _customersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (_allCustomers.isEmpty) return const Center(child: Text('No customers found.'));

              return RefreshIndicator(
                onRefresh: () async => handleRefresh(),
                child: _filteredCustomers.isEmpty
                    ? const Center(child: Text('No match found.'))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    return GestureDetector(
                      // Capture tap position for menu
                      onTapDown: _storePosition,
                      child: _CustomerCard(
                        customer: customer,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailPage(customerId: customer.id, customerName: customer.name))),
                        onLongPress: () => _showContextMenu(context, customer),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CustomerCard({required this.customer, required this.onTap, required this.onLongPress});

  ImageProvider? _getImage() {
    if (customer.imageUrl != null && customer.imageUrl!.isNotEmpty) {
      try {
        if (customer.imageUrl!.startsWith('data:')) {
          return MemoryImage(base64Decode(customer.imageUrl!.split(',')[1]));
        }
        return NetworkImage(customer.imageUrl!);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.indigo.shade50,
                backgroundImage: _getImage(),
                child: _getImage() == null
                    ? Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 22, color: Colors.indigo, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(customer.phoneNumber, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Stats Badges
                    Row(
                      children: [
                        if (customer.overdueLoanCount > 0)
                          _StatBadge(label: "Overdue", count: customer.overdueLoanCount, color: Colors.red.shade100, textColor: Colors.red.shade900),
                        if (customer.activeLoanCount > 0)
                          _StatBadge(label: "Active", count: customer.activeLoanCount, color: Colors.green.shade100, textColor: Colors.green.shade900),
                        if (customer.paidLoanCount > 0)
                          _StatBadge(label: "Closed", count: customer.paidLoanCount, color: Colors.grey.shade200, textColor: Colors.grey.shade800),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color textColor;
  const _StatBadge({required this.label, required this.count, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text("$count $label", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }
}