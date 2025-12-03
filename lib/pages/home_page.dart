import 'dart:convert'; // For Base64 decoding
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/models/business_settings_model.dart';
import 'package:pledge_loan_mobile/models/branch_model.dart';
import 'package:pledge_loan_mobile/pages/day_book_page.dart';
import 'package:pledge_loan_mobile/pages/reports_page.dart';
import 'package:pledge_loan_mobile/pages/manage_staff_page.dart';
import 'package:pledge_loan_mobile/pages/manage_branches_page.dart';
import 'package:pledge_loan_mobile/pages/loan_detail_page.dart';
import 'package:pledge_loan_mobile/pages/customer_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  String? _userRole;

  // Branch Switching State
  List<Branch> _branches = [];
  int? _selectedBranchId; // Null = All Branches
  String _selectedBranchName = "All Branches";

  // Futures
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<BusinessSettings> _settingsFuture;
  late Future<List<dynamic>> _recentCreatedFuture;
  late Future<List<dynamic>> _recentClosedFuture;

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  Future<void> _loadInitData() async {
    await _loadUserRole();
    if (_userRole == 'admin') {
      try {
        final branches = await _apiService.getBranches();
        if (mounted) setState(() => _branches = branches);
      } catch (e) {
        print("Error loading branches: $e");
      }
    }
    _refreshAll();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('role'));
  }

  Future<void> _refreshAll() async {
    setState(() {
      _statsFuture = _apiService.getDashboardStats(branchId: _selectedBranchId);
      // Fetches settings for the specific branch ID to update Address/Phone correctly
      _settingsFuture = _apiService.getBusinessSettings();
      _recentCreatedFuture = _apiService.getRecentCreatedLoans(branchId: _selectedBranchId);
      _recentClosedFuture = _apiService.getRecentClosedLoans(branchId: _selectedBranchId);
    });
  }

  // --- HELPER: Handle Base64 vs Network Images ---
  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return const AssetImage('assets/images/sri_kubera_logo.png'); // Fallback
      }
    }
    return NetworkImage(url);
  }

  void _showBranchSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Branch View", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.business, color: Colors.indigo),
              title: const Text("All Branches"),
              trailing: _selectedBranchId == null ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: () {
                setState(() {
                  _selectedBranchId = null;
                  _selectedBranchName = "All Branches";
                });
                Navigator.pop(context);
                _refreshAll();
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _branches.length,
                itemBuilder: (context, index) {
                  final b = _branches[index];
                  return ListTile(
                    leading: const Icon(Icons.store_mall_directory, color: Colors.grey),
                    title: Text(b.branchName),
                    trailing: _selectedBranchId == b.id ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      setState(() {
                        _selectedBranchId = b.id;
                        _selectedBranchName = b.branchName;
                      });
                      Navigator.pop(context);
                      _refreshAll();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 24)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () => showSearch(context: context, delegate: SmartSearchDelegate(_apiService)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- 1. BRANCH SELECTOR PILL (Admin Only) ---
              if (_userRole == 'admin' && _branches.isNotEmpty)
                Center(
                  child: GestureDetector(
                    onTap: _showBranchSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.indigo, size: 18),
                          const SizedBox(width: 8),
                          Text(_selectedBranchName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14)),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.indigo, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

              // --- 2. BUSINESS HEADER (Logo & Address) ---
              FutureBuilder<BusinessSettings>(
                future: _settingsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox(height: 10);
                  final s = snapshot.data!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            image: s.logoUrl != null
                                ? DecorationImage(image: _getImageProvider(s.logoUrl!), fit: BoxFit.cover)
                                : null,
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5)],
                          ),
                          child: s.logoUrl == null ? const Icon(Icons.business, color: Colors.grey) : null,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                              if (s.address != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(s.address!, style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              if (s.phoneNumber != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text("📞 ${s.phoneNumber}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // --- 3. REDESIGNED HERO CARD ---
              FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                  }
                  final stats = snapshot.data ?? {};
                  return _buildHeroCard(stats);
                },
              ),

              const SizedBox(height: 30),

              // --- 4. ACTION GRID ---
              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              _buildActionGrid(),

              const SizedBox(height: 30),

              // --- 5. RECENT ACTIVITY ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  TextButton(onPressed: _refreshAll, child: const Text("See All")),
                ],
              ),
              const SizedBox(height: 10),

              // Custom Tabs for Recent Activity
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.indigo,
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey[700],
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: "New Loans"),
                          Tab(text: "Recently Closed"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: [
                          _buildActivityList(_recentCreatedFuture, isClosed: false),
                          _buildActivityList(_recentClosedFuture, isClosed: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HERO CARD WIDGET ---
  Widget _buildHeroCard(Map<String, dynamic> stats) {
    // 1. Map 'totalPrincipalOut' (Active+Overdue) to the Main Display
    final totalPrincipal = num.tryParse(stats['totalPrincipalOut']?.toString() ?? '0') ?? 0.0;

    // 2. Map other stats
    final interestCollected = num.tryParse(stats['interestCollectedThisMonth']?.toString() ?? '0') ?? 0.0;
    final activeCount = stats['loansActive'] ?? 0;
    final overdueCount = stats['loansOverdue'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], // Deep Blue Professional Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E3C72).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: -30, child: Icon(Icons.account_balance_wallet, size: 200, color: Colors.white.withOpacity(0.05))),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Outstanding Principal", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(
                  '₹${totalPrincipal.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),

                // Detailed Breakdown Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Principal", style: TextStyle(color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text("₹${totalPrincipal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Interest (Month)", style: TextStyle(color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text("₹${interestCollected.toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Counters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCounterBadge(Icons.check_circle_outline, "Active Loans", activeCount.toString(), Colors.greenAccent),
                    _buildCounterBadge(Icons.warning_amber_rounded, "Overdue Loans", overdueCount.toString(), Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBadge(IconData icon, String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  // --- ACTIVITY LIST WIDGET ---
  Widget _buildActivityList(Future<List<dynamic>> future, {required bool isClosed}) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text("No recent activity", style: TextStyle(color: Colors.grey)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 0),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final loan = snapshot.data![index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)]),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: isClosed ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Icon(
                      isClosed ? Icons.check : Icons.account_balance_wallet,
                      color: isClosed ? Colors.green : Colors.blue,
                      size: 20
                  ),
                ),
                title: Text(loan['customer_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Loan #${loan['book_loan_number'] ?? loan['id']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                trailing: Text("₹${loan['principal_amount']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => LoanDetailPage(loanId: loan['id']),
                  ));
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- ACTION GRID ---
  Widget _buildActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _ActionBtn(label: "Day Book", icon: Icons.menu_book, color: Colors.purple, onTap: () => _nav(const DayBookPage())),
        if (_userRole == 'admin' || _userRole == 'manager')
          _ActionBtn(label: "Reports", icon: Icons.bar_chart, color: Colors.teal, onTap: () => _nav(const ReportsPage())),
        if (_userRole == 'admin') ...[
          _ActionBtn(label: "Staff", icon: Icons.people, color: Colors.orange, onTap: () => _nav(const ManageStaffPage())),
          _ActionBtn(label: "Branches", icon: Icons.store, color: Colors.brown, onTap: () => _nav(const ManageBranchesPage())),
        ]
      ],
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// --- SMART SEARCH DELEGATE (No Changes) ---
class SmartSearchDelegate extends SearchDelegate {
  final ApiService apiService;
  SmartSearchDelegate(this.apiService);

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) return const Center(child: Text("Type at least 2 chars...", style: TextStyle(color: Colors.grey)));
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: apiService.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No results found"));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (ctx, i) => const Divider(),
          itemBuilder: (ctx, i) {
            final item = snapshot.data![i];
            final bool isLoan = item['type'] == 'loan';

            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isLoan ? Colors.blue.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(isLoan ? Icons.receipt_long : Icons.person, color: isLoan ? Colors.blue : Colors.green),
              ),
              title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['subtitle'] ?? ''),
              onTap: () {
                if (isLoan) {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => LoanDetailPage(loanId: item['id'])));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => CustomerDetailPage(
                    customerId: item['id'],
                    customerName: item['title'],
                  )));
                }
              },
            );
          },
        );
      },
    );
  }
}