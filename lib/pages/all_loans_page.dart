// lib/pages/all_loans_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/loan_detail_page.dart'; // <-- 1. IMPORT NEW PAGE

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

  final List<String> _statusFilters = ['all', 'active', 'overdue', 'paid', 'forfeited'];
  String _selectedStatusFilter = 'all';

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
        _filterLoans();
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
        final statusMatch = _selectedStatusFilter == 'all' ||
            loan.status == _selectedStatusFilter;
        if (!statusMatch) return false;
        if (searchTerm.isEmpty) return true;
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
      _selectedStatusFilter = 'all';
      _searchController.clear();
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
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statusFilters.map((status) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(status[0].toUpperCase() + status.substring(1)),
                    selected: _selectedStatusFilter == status,
                    onSelected: (isSelected) {
                      if (isSelected) {
                        setState(() {
                          _selectedStatusFilter = status;
                          _filterLoans();
                        });
                      }
                    },
                    selectedColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: _selectedStatusFilter == status ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
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
                      ? const Center(child: Text('No loans match your filters.'))
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
                          // --- 2. UPDATE THE ONTAP ---
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LoanDetailPage(loanId: loan.id),
                              ),
                            ).then((_) {
                              // This re-runs the load/filter when you come back
                              _handleRefresh();
                            });
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