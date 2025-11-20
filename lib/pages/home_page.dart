// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/day_book_page.dart';
import 'package:pledge_loan_mobile/pages/reports_page.dart';
import 'package:pledge_loan_mobile/pages/manage_staff_page.dart'; // --- NEW IMPORT

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService().getDashboardStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No data found.'));
        }

        final stats = snapshot.data!;
        final totalCustomers = stats['totalCustomers'] ?? 0;
        final totalLoans = stats['totalLoans'] ?? 0;
        final totalValue = stats['totalValue'] ?? 0.0;

        final loansActive = stats['loansActive'] ?? 0;
        final loansPaid = stats['loansPaid'] ?? 0;
        final loansOverdue = stats['loansOverdue'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              // 1. Customers
              DashboardCard(
                title: 'Total Customers',
                icon: Icons.people,
                color: Colors.blue,
                statsContent: Text(totalCustomers.toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              ),

              // 2. Loans
              DashboardCard(
                title: 'Total Loans',
                icon: Icons.monetization_on,
                color: Colors.green,
                statsContent: LoanStatsColumn(total: totalLoans, active: loansActive, paid: loansPaid, overdue: loansOverdue),
              ),

              // 3. Value
              DashboardCard(
                title: 'Total Loan Value',
                icon: Icons.account_balance_wallet,
                color: Colors.orange,
                statsContent: Text('₹${(num.tryParse(totalValue.toString()) ?? 0.0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ),

              // 4. Day Book
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookPage())),
                child: const DashboardCard(
                  title: 'Day Book',
                  icon: Icons.book,
                  color: Colors.purple,
                  statsContent: Center(child: Text("View\nLedger", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
              ),

              // 5. Reports (Only if Admin)
              if (_userRole == 'admin')
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage())),
                  child: const DashboardCard(
                    title: 'Reports',
                    icon: Icons.analytics,
                    color: Colors.teal,
                    statsContent: Center(child: Text("Profit\n& Loss", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                  ),
                ),

              // 6. Manage Staff (Only if Admin)
              if (_userRole == 'admin')
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageStaffPage())),
                  child: const DashboardCard(
                    title: 'Manage Staff',
                    icon: Icons.manage_accounts,
                    color: Colors.blueGrey,
                    statsContent: Center(child: Text("Users\n& Roles", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// --- 5. New Flexible DashboardCard ---
class DashboardCard extends StatelessWidget {
  final String title;
  final Widget statsContent; // Changed from String to Widget
  final IconData icon;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.statsContent, // Changed
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withAlpha(180), color], // Use withAlpha
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const Spacer(),
            statsContent, // Display the custom widget here
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 6. New Helper Widget for the Loan Stats ---
class LoanStatsColumn extends StatelessWidget {
  final int total;
  final int active;
  final int paid;
  final int overdue;

  const LoanStatsColumn({
    super.key,
    required this.total,
    required this.active,
    required this.paid,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, color: Colors.white);
    const boldStyle = TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(total.toString(), style: boldStyle), // Total
        const SizedBox(height: 8),
        Text("Active: $active", style: style),
        Text("Paid: $paid", style: style),
        Text("Overdue: $overdue", style: style),
      ],
    );
  }
}