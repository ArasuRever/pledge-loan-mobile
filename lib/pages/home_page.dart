// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/day_book_page.dart';
import 'package:pledge_loan_mobile/pages/reports_page.dart';
import 'package:pledge_loan_mobile/pages/manage_staff_page.dart';
import 'package:pledge_loan_mobile/pages/new_loan_workflow_page.dart'; // Assuming you have this, or link to Add Customer

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userRole;
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _statsFuture = ApiService().getDashboardStats();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('role'));
  }

  Future<void> _refreshStats() async {
    setState(() {
      _statsFuture = ApiService().getDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Sri Kubera Bankers', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshStats),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStats,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading dashboard.\n${snapshot.error}'));
            }

            final stats = snapshot.data ?? {};
            final totalValue = stats['totalValue'] ?? 0.0;
            final totalCustomers = stats['totalCustomers'] ?? 0;
            final activeLoans = stats['loansActive'] ?? 0;
            final overdueLoans = stats['loansOverdue'] ?? 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- 1. HERO CARD (Total Value) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF283593)], // Navy Gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Outstanding Value", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '₹${(num.tryParse(totalValue.toString()) ?? 0.0).toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _HeroStatBadge(label: "Overdue", value: overdueLoans.toString(), color: Colors.redAccent),
                          const SizedBox(width: 12),
                          _HeroStatBadge(label: "Active", value: activeLoans.toString(), color: Colors.greenAccent),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text("Quick Stats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                const SizedBox(height: 12),

                // --- 2. QUICK STATS ROW ---
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.people, label: "Customers", value: totalCustomers.toString(), color: Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.account_balance, label: "Total Loans", value: (stats['totalLoans'] ?? 0).toString(), color: Colors.orange)),
                  ],
                ),

                const SizedBox(height: 24),
                const Text("Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                const SizedBox(height: 12),

                // --- 3. ACTION GRID ---
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _ActionCard(
                      title: "Day Book",
                      icon: Icons.menu_book,
                      color: Colors.purple,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookPage())),
                    ),
                    if (_userRole == 'admin')
                      _ActionCard(
                        title: "Reports",
                        icon: Icons.bar_chart,
                        color: Colors.teal,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage())),
                      ),
                    if (_userRole == 'admin')
                      _ActionCard(
                        title: "Staff",
                        icon: Icons.badge,
                        color: Colors.blueGrey,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageStaffPage())),
                      ),
                    // You can add more cards here later (e.g. Recycle Bin)
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _HeroStatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeroStatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text("$value $label", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }
}