// lib/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/pages/home_page.dart';
import 'package:pledge_loan_mobile/pages/manage_staff_page.dart';
import 'package:pledge_loan_mobile/pages/customers_page.dart';
import 'package:pledge_loan_mobile/pages/new_loan_workflow_page.dart';
import 'package:pledge_loan_mobile/pages/all_loans_page.dart';
// 1. IMPORT THE NEW PAGE
import 'package:pledge_loan_mobile/pages/add_customer_page.dart';

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

  // 2. CREATE A GLOBAL KEY FOR THE CUSTOMERS PAGE
  final _customerPageKey = GlobalKey<CustomersPageState>();

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

    if (role == 'admin') {
      setState(() {
        _userRole = 'admin';
        _widgetOptions = [
          const HomePage(),
          CustomersPage(key: _customerPageKey), // 3. ASSIGN THE KEY
          const NewLoanWorkflowPage(),
          const AllLoansPage(),
        ];
        _navBarItems = [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'New Loan'),
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Loans'),
        ];
        _selectedIndex = 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _userRole = 'staff';
        _widgetOptions = [
          CustomersPage(key: _customerPageKey), // 3. ASSIGN THE KEY
          const NewLoanWorkflowPage(),
          const AllLoansPage(),
        ];
        _navBarItems = [
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'New Loan'),
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Loans'),
        ];
        _selectedIndex = 0;
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
    String currentTabLabel = _navBarItems[_selectedIndex].label!;

    if (currentTabLabel == 'Customers') {
      return FloatingActionButton(
        // 4. UPDATE THE ONPRESSED FUNCTION
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddCustomerPage()),
          ).then((didAddCustomer) {
            // This runs when we come back from the AddCustomerPage
            if (didAddCustomer == true) {
              // Call the public refresh method on the CustomersPage
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