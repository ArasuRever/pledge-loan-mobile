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
import 'package:pledge_loan_mobile/pages/business_settings_page.dart'; // <--- IMPORT NEW PAGE

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
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Loans'),
        ];
        _selectedIndex = 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _userRole = 'staff';
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
    } else if (value == 'manage_staff') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ManageStaffPage()));
    } else if (value == 'recycle_bin') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RecycleBinPage()));
    } else if (value == 'reports') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReportsPage()));
    } else if (value == 'settings') { // <--- NEW SETTINGS HANDLER
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BusinessSettingsPage()));
    }
  }

  Widget? _getFloatingActionButton() {
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
              if (_userRole == 'admin') ...[
                const PopupMenuItem(value: 'manage_staff', child: Row(children: [Icon(Icons.people, color: Colors.grey), SizedBox(width: 8), Text('Manage Staff')])),
                const PopupMenuItem(value: 'recycle_bin', child: Row(children: [Icon(Icons.delete, color: Colors.grey), SizedBox(width: 8), Text('Recycle Bin')])),
                const PopupMenuItem(value: 'reports', child: Row(children: [Icon(Icons.bar_chart, color: Colors.grey), SizedBox(width: 8), Text('Financial Reports')])),
                const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, color: Colors.grey), SizedBox(width: 8), Text('Business Settings')])), // <--- NEW MENU ITEM
                const PopupMenuDivider(),
              ],
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