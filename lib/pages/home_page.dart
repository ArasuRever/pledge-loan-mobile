// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart'; // <-- THE FIX

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold is provided by main_scaffold.dart, so we just return the body
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService().getDashboardStats(), // Now ApiService() is found
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

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              DashboardCard(
                title: 'Total Customers',
                value: totalCustomers.toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
              DashboardCard(
                title: 'Total Loans',
                value: totalLoans.toString(),
                icon: Icons.monetization_on,
                color: Colors.green,
              ),
              DashboardCard(
                title: 'Total Loan Value',
                value: '₹${(num.tryParse(totalValue.toString()) ?? 0.0).toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet,
                color: Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ... (DashboardCard class remains the same as before) ...
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
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
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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