// lib/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/pages/home_page.dart';

// --- Placeholder Pages ---
// We create these so the navigation bar works. We'll build them for real next.
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: Theme.of(context).textTheme.headlineSmall));
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScaffold({super.key, required this.onLogout});

  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  String? _userRole;
  String _username = '';
  List<Widget> _pages = [];

  // This is used to build the page titles in the AppBar
  List<String> _pageTitles = [];

  @override
  void initState() {
    super.initState();
    _decodeTokenAndBuildPages();
  }

  Future<void> _decodeTokenAndBuildPages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    String role = 'staff'; // Default to staff if something is wrong
    String username = 'User';

    if (token != null) {
      try {
        // Decode the token payload
        Map<String, dynamic> payload = Jwt.parseJwt(token);
        role = payload['role'];
        username = payload['username'];
      } catch (e) {
        print("Error decoding token: $e");
        widget.onLogout(); // Log out if token is bad
      }
    } else {
      widget.onLogout(); // Log out if no token
    }

    setState(() {
      _userRole = role;
      _username = username;

      // Build the list of pages based on the user's role
      _pages = [
        HomePage(userRole: _userRole!),
        const PlaceholderPage(title: 'Customers'),
        const PlaceholderPage(title: 'All Loans'),
        const PlaceholderPage(title: 'New Loan'),
        if (_userRole == 'admin') // Conditionally add Manage Staff page
          const PlaceholderPage(title: 'Manage Staff'),
      ];

      // Build the list of titles for the AppBar
      _pageTitles = [
        'Dashboard',
        'Customers',
        'All Loans',
        'New Loan',
        if (_userRole == 'admin')
          'Manage Staff',
      ];
    });
  }

  // --- This is for the Bottom Navigation Bar ---
  List<BottomNavigationBarItem> _buildNavItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.people_outline),
        activeIcon: Icon(Icons.people),
        label: 'Customers',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.list_alt_outlined),
        activeIcon: Icon(Icons.list_alt),
        label: 'Loans',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle_outline),
        activeIcon: Icon(Icons.add_circle),
        label: 'New Loan',
      ),
      if (_userRole == 'admin') // Conditionally add Manage Staff tab
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Staff',
        ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner until the role is determined
    if (_userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).textTheme.headlineSmall?.color,
        elevation: 1,
        actions: [
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                widget.onLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Logged in as $_username ($_userRole)'),
                enabled: false,
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: _buildNavItems(),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Shows labels for all items
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 5,
      ),
    );
  }
}