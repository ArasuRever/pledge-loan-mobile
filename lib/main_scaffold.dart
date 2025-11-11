// lib/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/pages/home_page.dart';
import 'package:pledge_loan_mobile/pages/manage_staff_page.dart';
import 'package:pledge_loan_mobile/pages/customers_page.dart';
import 'package:pledge_loan_mobile/pages/new_loan_workflow_page.dart';
import 'package:pledge_loan_mobile/pages/all_loans_page.dart';

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

  // We will build these lists *after* we know the user's role
  List<Widget> _widgetOptions = [];
  List<BottomNavigationBarItem> _navBarItems = [];

  @override
  void initState() {
    super.initState();
    _loadRoleAndBuildUI();
  }

  Future<void> _loadRoleAndBuildUI() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');

    if (role == null) {
      widget.onLogout();
      return;
    }

    // --- THIS IS THE NEW LOGIC ---
    if (role == 'admin') {
      // ADMIN UI
      setState(() {
        _userRole = 'admin';
        _widgetOptions = [
          const HomePage(), // Dashboard
          const CustomersPage(),
          const NewLoanWorkflowPage(),
          const AllLoansPage(),
        ];
        _navBarItems = [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'New Loan'),
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Loans'),
        ];
        _selectedIndex = 0; // Default to Dashboard
        _isLoading = false;
      });
    } else {
      // STAFF UI
      setState(() {
        _userRole = 'staff';
        // We *remove* the Dashboard page from the list
        _widgetOptions = [
          const CustomersPage(),
          const NewLoanWorkflowPage(),
          const AllLoansPage(),
        ];
        _navBarItems = [
          // We *remove* the Dashboard tab
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'New Loan'),
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Loans'),
        ];
        _selectedIndex = 0; // Default to Customers page
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onMenuSelected(String value) {
    if (value == 'logout') {
      widget.onLogout();
    }
    if (value == 'manage_staff') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ManageStaffPage()),
      );
    }
  }

  Widget? _getFloatingActionButton() {
    // Check role and selected tab
    String currentTabLabel = _navBarItems[_selectedIndex].label!;

    if (currentTabLabel == 'Customers') {
      return FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TODO: Add New Customer')),
          );
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
              // Only admin sees Manage Staff
              if (_userRole == 'admin')
                const PopupMenuItem(
                  value: 'manage_staff',
                  child: Text('Manage Staff'),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: _getFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        items: _navBarItems, // Use the dynamic list of items
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}