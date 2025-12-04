// lib/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/pages/home_page.dart';
import 'package:pledge_loan_mobile/pages/manage_staff_page.dart';
import 'package:pledge_loan_mobile/pages/customers_page.dart';
import 'package:pledge_loan_mobile/pages/new_loan_workflow_page.dart';
import 'package:pledge_loan_mobile/pages/all_loans_page.dart';
import 'package:pledge_loan_mobile/pages/add_customer_page.dart';
import 'package:pledge_loan_mobile/pages/recycle_bin_page.dart';
import 'package:pledge_loan_mobile/pages/reports_page.dart';
import 'package:pledge_loan_mobile/pages/business_settings_page.dart';

class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScaffold({super.key, required this.onLogout});

  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  String? _userRole;
  bool _isLoading = true;

  final _customerPageKey = GlobalKey<CustomersPageState>();

  List<Widget> _widgetOptions = [];
  List<BottomNavigationBarItem> _navBarItems = [];

  // Getters for role checks
  bool get isAdmin => _userRole == 'admin';
  bool get isManager => _userRole == 'manager';

  @override
  void initState() {
    super.initState();
    _loadRoleAndBuildUI();
  }

  Future<void> _loadRoleAndBuildUI() async {
    final prefs = await SharedPreferences.getInstance();
    // Normalize role string to prevent mismatch (e.g. "Manager" vs "manager")
    final rawRole = prefs.getString('role');
    final role = rawRole?.toLowerCase().trim();

    if (role == null) {
      widget.onLogout();
      return;
    }

    setState(() {
      _userRole = role;

      // FIX: Allow BOTH Admin AND Manager to see the Dashboard view
      if (isAdmin || isManager) {
        _widgetOptions = [
          const HomePage(), // Dashboard
          CustomersPage(key: _customerPageKey),
          const NewLoanWorkflowPage(),
          const AllLoansPage(),
        ];
        _navBarItems = [
          const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Customers'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle), label: 'New Loan'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.list), label: 'All Loans'),
        ];
      } else {
        // Staff View (No Dashboard)
        _widgetOptions = [
          CustomersPage(key: _customerPageKey),
          const NewLoanWorkflowPage(),
          const AllLoansPage(),
        ];
        _navBarItems = [
          const BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Customers'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle), label: 'New Loan'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.list), label: 'All Loans'),
        ];
      }

      _selectedIndex = 0;
      _isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onMenuSelected(String value) {
    if (value == 'logout') {
      widget.onLogout();
    } else if (value == 'manage_staff') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ManageStaffPage()));
    } else if (value == 'recycle_bin') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RecycleBinPage()));
    } else if (value == 'reports') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReportsPage()));
    } else if (value == 'settings') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BusinessSettingsPage()));
    }
  }

  Widget? _getFloatingActionButton() {
    if (_navBarItems.isEmpty) return null;

    String currentTabLabel = _navBarItems[_selectedIndex].label!;

    if (currentTabLabel == 'Customers') {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => const AddCustomerPage()))
              .then((didAddCustomer) {
            if (didAddCustomer == true) {
              _customerPageKey.currentState?.handleRefresh();
            }
          });
        },
        tooltip: 'Add Customer',
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pledge Loan Manager'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              // 1. Admin Only Items
              if (isAdmin) ...[
                const PopupMenuItem(value: 'manage_staff', child: Row(children: [Icon(Icons.people, color: Colors.grey), SizedBox(width: 8), Text('Manage Staff')])),
                const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, color: Colors.grey), SizedBox(width: 8), Text('Business Settings')])),
              ],

              // 2. Admin AND Manager Items (FIX: Added Manager check here)
              if (isAdmin || isManager) ...[
                const PopupMenuItem(value: 'reports', child: Row(children: [Icon(Icons.bar_chart, color: Colors.grey), SizedBox(width: 8), Text('Financial Reports')])),
                const PopupMenuItem(value: 'recycle_bin', child: Row(children: [Icon(Icons.delete, color: Colors.grey), SizedBox(width: 8), Text('Recycle Bin')])),
                const PopupMenuDivider(),
              ],

              // 3. All Users
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.grey), SizedBox(width: 8), Text('Logout')])),
            ],
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: _getFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        items: _navBarItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}