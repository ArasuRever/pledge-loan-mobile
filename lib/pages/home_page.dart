// lib/pages/home_page.dart
import 'dart:convert';
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
    // 1. CRITICAL FIX: Initialize futures IMMEDIATELY with default (null/All)
    // This prevents the red screen because variables are assigned before build() runs.
    _initializeFutures();

    // 2. Then load the saved preference in the background and refresh
    _loadSavedBranch();

    // 3. Load user role/data
    _loadInitData();
  }

  Future<void> _loadSavedBranch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('current_branch_view')) {
      if (mounted) {
        setState(() {
          _selectedBranchId = prefs.getInt('current_branch_view');
          _selectedBranchName = prefs.getString('current_branch_name') ?? "Branch";
          // Re-initialize with the loaded ID
          _initializeFutures();
        });
      }
    }
  }

  void _initializeFutures() {
    _statsFuture = _apiService.getDashboardStats(branchId: _selectedBranchId);
    _settingsFuture = _apiService.getBusinessSettings(branchId: _selectedBranchId);
    _recentCreatedFuture = _apiService.getRecentCreatedLoans(branchId: _selectedBranchId);
    _recentClosedFuture = _apiService.getRecentClosedLoans(branchId: _selectedBranchId);
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
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('role'));
  }

  Future<void> _refreshAll() async {
    setState(() {
      _initializeFutures();
    });
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return const AssetImage('assets/images/sri_kubera_logo.png');
      }
    }
    return NetworkImage(url);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name[0].toUpperCase();
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
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('current_branch_view');
                await prefs.setString('current_branch_name', "All Branches");

                setState(() {
                  _selectedBranchId = null;
                  _selectedBranchName = "All Branches";
                  _initializeFutures();
                });
                Navigator.pop(context);
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
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('current_branch_view', b.id);
                      await prefs.setString('current_branch_name', b.branchName);

                      setState(() {
                        _selectedBranchId = b.id;
                        _selectedBranchName = b.branchName;
                        _initializeFutures();
                      });
                      Navigator.pop(context);
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
              if (_userRole == 'admin' && _branches.isNotEmpty)
                Center(
                  child: GestureDetector(
                    onTap: _showBranchSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          Icon(Icons.location_on, color: Colors.indigo.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text(_selectedBranchName, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700, fontSize: 13)),
                          const SizedBox(width: 8),
                          Icon(Icons.keyboard_arrow_down, color: Colors.indigo.shade700, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),

              FutureBuilder<BusinessSettings>(
                future: _settingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 50); // Silent loading for smoother UX
                  }
                  if (snapshot.hasError) {
                    return const SizedBox(); // Hide header on error
                  }
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
                              Text(s.businessName.isNotEmpty ? s.businessName : "Business Name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                              if (s.address.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: 2), child: Text(s.address, style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              if (s.phoneNumber.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: 2), child: Text("📞 ${s.phoneNumber}", style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

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
              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              _buildActionGrid(),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  TextButton(onPressed: _refreshAll, child: const Text("Refresh")),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
                          child: TabBar(
                            indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                            labelColor: Colors.black87,
                            unselectedLabelColor: Colors.grey[500],
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            tabs: const [Tab(text: "New Loans"), Tab(text: "Recently Closed")],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 350,
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
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Keep existing _buildHeroCard, _buildCounterBadge, _buildActivityList, _buildActivityRow, _buildActionGrid)
  // Re-paste them from your previous correct version or let me know if you need them included again.
  // For brevity, assuming widgets are unchanged from the previous working version.

  Widget _buildHeroCard(Map<String, dynamic> stats) {
    final totalPrincipal = num.tryParse(stats['totalPrincipalOut']?.toString() ?? '0') ?? 0.0;
    final totalInterestAccrued = num.tryParse(stats['totalInterestAccrued']?.toString() ?? '0') ?? 0.0;
    final activeCount = stats['loansActive'] ?? 0;
    final overdueCount = stats['loansOverdue'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3C72).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.account_balance, size: 180, color: Colors.white.withOpacity(0.05))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Outstanding Principal", style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text('₹${totalPrincipal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Principal", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text("₹${totalPrincipal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ])),
                      Container(width: 1, height: 30, color: Colors.white24),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Accrued Interest", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text("₹${totalInterestAccrued.toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                      ])),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCounterBadge(Icons.check_circle_outline, "Active", activeCount.toString(), Colors.greenAccent),
                    _buildCounterBadge(Icons.warning_amber_rounded, "Overdue", overdueCount.toString(), Colors.redAccent),
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
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(30)),
      child: Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
    );
  }

  Widget _buildActivityList(Future<List<dynamic>> future, {required bool isClosed}) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text(isClosed ? "No closed loans recently" : "No new loans recently", style: TextStyle(color: Colors.grey[500]))]));
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: snapshot.data!.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 70, endIndent: 20),
          itemBuilder: (context, index) {
            final loan = snapshot.data![index];
            return _buildActivityRow(loan, isClosed);
          },
        );
      },
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> loan, bool isClosed) {
    final themeColor = isClosed ? Colors.green.shade700 : Colors.indigo.shade600;
    final String customerName = loan['customer_name'] ?? 'Unknown';
    final String loanNo = loan['book_loan_number'] ?? loan['id'].toString();
    final String amount = loan['principal_amount']?.toString() ?? '0';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (c) => LoanDetailPage(loanId: loan['id'])));
      },
      leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle), alignment: Alignment.center, child: Text(_getInitials(customerName), style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16))),
      title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)), child: Text("Loan #$loanNo", style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600)))])),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("₹$amount", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: themeColor)), if (isClosed) const Text("Settled", style: TextStyle(fontSize: 10, color: Colors.green))]),
    );
  }

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
        if (_userRole == 'admin' || _userRole == 'manager') _ActionBtn(label: "Reports", icon: Icons.bar_chart, color: Colors.teal, onTap: () => _nav(const ReportsPage())),
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

// ... (SmartSearchDelegate and _ActionBtn remain as they were)
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 26)), const SizedBox(height: 10), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))]),
      ),
    );
  }
}

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
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isLoan ? Colors.blue.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(isLoan ? Icons.receipt_long : Icons.person, color: isLoan ? Colors.blue : Colors.green)),
              title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['subtitle'] ?? ''),
              onTap: () {
                if (isLoan) Navigator.push(context, MaterialPageRoute(builder: (c) => LoanDetailPage(loanId: item['id'])));
                else Navigator.push(context, MaterialPageRoute(builder: (c) => CustomerDetailPage(customerId: item['id'], customerName: item['title'])));
              },
            );
          },
        );
      },
    );
  }
}