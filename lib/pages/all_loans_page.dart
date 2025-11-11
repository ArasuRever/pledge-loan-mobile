// lib/pages/all_loans_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart'; // <-- THE FIX
import 'package:pledge_loan_mobile/services/api_service.dart'; // <-- THE FIX

class AllLoansPage extends StatefulWidget {
  const AllLoansPage({super.key});

  @override
  State<AllLoansPage> createState() => _AllLoansPageState();
}

class _AllLoansPageState extends State<AllLoansPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Loan>> _loansFuture;
  List<Loan> _allLoans = [];
  List<Loan> _filteredLoans = [];

  @override
  void initState() {
    super.initState();
    _loansFuture = _loadLoans();
    _searchController.addListener(_filterLoans);
  }

  Future<List<Loan>> _loadLoans() async {
    try {
      final loans = await _apiService.getLoans();
      setState(() {
        _allLoans = loans;
        _filteredLoans = loans;
      });
      return loans;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  void _filterLoans() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredLoans = _allLoans.where((loan) {
        final nameMatch = loan.customerName.toLowerCase().contains(searchTerm);
        final phoneMatch = loan.phoneNumber?.contains(searchTerm) ?? false;
        final bookMatch = loan.bookLoanNumber?.toLowerCase().contains(searchTerm) ?? false;
        return nameMatch || phoneMatch || bookMatch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'overdue': return Colors.red;
      case 'active': return Colors.green;
      case 'paid': return Colors.blueGrey;
      case 'forfeited': return Colors.black54;
      default: return Colors.black;
    }
  }

  Future<void> _handleRefresh() async {
    final future = _loadLoans();
    setState(() {
      _loansFuture = future;
    });
    await future;
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
              labelText: 'Search Loans',
              hintText: 'Search by name, phone, or book #...',
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
            child: FutureBuilder<List<Loan>>(
              future: _loansFuture,
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
                if (_allLoans.isEmpty) {
                  return const Center(child: Text('No loans found.'));
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: _filteredLoans.isEmpty
                      ? const Center(child: Text('No loans match your search.'))
                      : ListView.builder(
                    itemCount: _filteredLoans.length,
                    itemBuilder: (context, index) {
                      final loan = _filteredLoans[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(loan.customerName),
                          subtitle: Text('Book #: ${loan.bookLoanNumber ?? 'N/A'} - ${loan.formattedPrincipal}'),
                          trailing: Text(
                            loan.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(loan.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tapped on Loan #${loan.id}')),
                            );
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