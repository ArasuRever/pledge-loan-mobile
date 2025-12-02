// lib/pages/all_loans_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/loan_detail_page.dart';

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
      if (mounted) {
        setState(() {
          _allLoans = loans;
          _filterLoans();
        });
      }
      return loans;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  void _filterLoans() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredLoans = _allLoans.where((loan) {
        final statusMatch = _selectedStatusFilter == 'all' || loan.status == _selectedStatusFilter;
        if (!statusMatch) return false;
        if (searchTerm.isEmpty) return true;

        final nameMatch = loan.customerName.toLowerCase().contains(searchTerm);
        // --- FIX: ADDED PHONE SEARCH BACK ---
        final phoneMatch = loan.phoneNumber?.contains(searchTerm) ?? false;
        final bookMatch = loan.bookLoanNumber?.toLowerCase().contains(searchTerm) ?? false;

        return nameMatch || phoneMatch || bookMatch;
      }).toList();
    });
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
    return Column(
      children: [
        // Filter & Search Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Name, Phone, or Book #', // Updated Hint
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                      : null,
                ),
              ),
              // ... Status Chips (Same as before) ...
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _statusFilters.map((status) {
                    final isSelected = _selectedStatusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(status.toUpperCase()),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) setState(() { _selectedStatusFilter = status; _filterLoans(); });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFF1A237E).withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF1A237E) : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade300)
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Loan List
        Expanded(
          child: FutureBuilder<List<Loan>>(
            future: _loansFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (_allLoans.isEmpty) return const Center(child: Text('No loans found.'));

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _filteredLoans.isEmpty
                    ? const Center(child: Text('No loans match.'))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredLoans.length,
                  itemBuilder: (context, index) => _LoanCard(loan: _filteredLoans[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// _LoanCard remains the same as previous update
class _LoanCard extends StatelessWidget {
  final Loan loan;
  const _LoanCard({required this.loan});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'overdue': return Colors.red;
      case 'active': return Colors.green;
      case 'paid': return Colors.grey;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(loan.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDetailPage(loanId: loan.id))),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loan.bookLoanNumber ?? 'ID: ${loan.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(loan.status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.customerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(loan.pledgeDate.split('T')[0], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  Text(loan.formattedPrincipal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}