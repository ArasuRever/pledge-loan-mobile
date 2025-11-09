// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'dart:convert';
import 'package:pledge_loan_mobile/services/api_service.dart'; // Import our service

class HomePage extends StatefulWidget {
  final String userRole; // Will be 'admin' or 'staff'
  const HomePage({super.key, required this.userRole});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService(); // Use our API service
  Map<String, dynamic>? _stats;
  List _recentLoans = [];
  List _closedLoans = [];
  bool _isLoading = true;
  String? _error;

  // Helper to format currency
  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use our new ApiService for all calls
      final recentPromise = _api.get('loans/recent/created');
      final closedPromise = _api.get('loans/recent/closed');

      if (widget.userRole == 'admin') {
        // Admin gets all three
        final statsPromise = _api.get('dashboard/stats');

        final responses = await Future.wait([statsPromise, recentPromise, closedPromise]);

        if (responses[0].statusCode == 200) {
          _stats = json.decode(responses[0].body);
        } else {
          throw Exception('Failed to load stats');
        }
        _recentLoans = json.decode(responses[1].body);
        _closedLoans = json.decode(responses[2].body);

      } else {
        // Staff only gets the two lists
        final responses = await Future.wait([recentPromise, closedPromise]);
        _recentLoans = json.decode(responses[0].body);
        _closedLoans = json.decode(responses[1].body);
      }

    } catch (e) {
      setState(() {
        _error = "Failed to load dashboard data. ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Welcome, ${widget.userRole}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          // --- Admin Stats Grid ---
          if (widget.userRole == 'admin' && _stats != null)
            _buildAdminStatsGrid(),

          const SizedBox(height: 24),

          // --- Recent Loans List ---
          _buildLoanListCard(
            title: "Recently Created Loans",
            loans: _recentLoans,
          ),

          const SizedBox(height: 16),

          // --- Closed Loans List ---
          _buildLoanListCard(
            title: "Recently Closed Loans",
            loans: _closedLoans,
            isMuted: true,
          ),
        ],
      ),
    );
  }

  // A widget for the 4 admin stat cards
  Widget _buildAdminStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Disables scrolling inside the ListView
      children: [
        _buildStatCard(
          title: "Total Principal Out",
          value: currencyFormat.format(_stats?['totalPrincipalOut'] ?? 0),
          color: Colors.blue.shade700,
        ),
        _buildStatCard(
          title: "Interest (This Month)",
          value: currencyFormat.format(_stats?['interestCollectedThisMonth'] ?? 0),
          color: Colors.green.shade700,
        ),
        _buildStatCard(
          title: "Total Active Loans",
          value: (_stats?['totalActiveLoans'] ?? 0).toString(),
          color: Colors.indigo.shade700,
        ),
        _buildStatCard(
          title: "Overdue Loans",
          value: (_stats?['totalOverdueLoans'] ?? 0).toString(),
          color: Colors.red.shade700,
        ),
      ],
    );
  }

  // A widget for one stat card
  Widget _buildStatCard({required String title, required String value, required Color color}) {
    return Card(
      elevation: 3,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // A widget for the "Recent" and "Closed" lists
  Widget _buildLoanListCard({required String title, required List loans, bool isMuted = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          if (loans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No loans to display."),
            ),
          ...loans.map((loan) {
            return ListTile(
              title: Text(
                "Loan #${loan['id']} for ${loan['customer_name']}",
                style: TextStyle(
                  color: isMuted ? Colors.grey[600] : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Text(
                currencyFormat.format(double.tryParse(loan['principal_amount'].toString()) ?? 0),
                style: TextStyle(
                  color: isMuted ? Colors.grey[600] : Colors.black,
                ),
              ),
              onTap: () {
                // TODO: Navigate to Loan Details Page
                // Navigator.push(context, MaterialPageRoute(builder: (context) => LoanPage(loanId: loan['id'])));
              },
            );
          }),
        ],
      ),
    );
  }
}