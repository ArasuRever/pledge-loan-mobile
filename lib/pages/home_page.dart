import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

        // --- 1. Read all the new stats from the API ---
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
            childAspectRatio: 0.85, // Make cards a bit taller
            children: [
              // --- 2. Customer Card (Unchanged) ---
              DashboardCard(
                title: 'Total Customers',
                icon: Icons.people,
                color: Colors.blue,
                // Pass a simple Text widget
                statsContent: Text(
                  totalCustomers.toString(),
                  style: const TextStyle(
                    fontSize: 32, // Larger font for single number
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              // --- 3. New "Total Loans" Card ---
              DashboardCard(
                title: 'Total Loans',
                icon: Icons.monetization_on,
                color: Colors.green,
                // Pass a Column with all the stats
                statsContent: LoanStatsColumn(
                  total: totalLoans,
                  active: loansActive,
                  paid: loansPaid,
                  overdue: loansOverdue,
                ),
              ),

              // --- 4. Total Value Card (Unchanged) ---
              DashboardCard(
                title: 'Total Loan Value',
                icon: Icons.account_balance_wallet,
                color: Colors.orange,
                statsContent: Text(
                  '₹${(num.tryParse(totalValue.toString()) ?? 0.0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24, // Smaller font to fit
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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