// lib/pages/manage_staff_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/user_model.dart';
import 'package:pledge_loan_mobile/models/branch_model.dart'; // Import Branch Model
import 'package:pledge_loan_mobile/services/api_service.dart';

class ManageStaffPage extends StatefulWidget {
  const ManageStaffPage({super.key});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  final ApiService _apiService = ApiService();

  List<User> _users = [];
  List<Branch> _branches = []; // Store available branches

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Fetch Users AND Branches in parallel
      final results = await Future.wait([
        _apiService.getStaff(),
        _apiService.getBranches(),
      ]);

      setState(() {
        _users = results[0] as List<User>;
        _branches = results[1] as List<Branch>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- REDESIGNED ADD USER MODAL ---
  Future<void> _showAddUserDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'staff';
    int? selectedBranchId; // Selected Branch

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a new staff member, manager, or admin.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Username Field
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.indigo),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // Role Selection Cards
              const Text("Select Access Level", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleSelector(
                      label: 'STAFF',
                      icon: Icons.person,
                      color: Colors.blue,
                      isSelected: role == 'staff',
                      onTap: () => setSheetState(() => role = 'staff'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRoleSelector(
                      label: 'MANAGER',
                      icon: Icons.manage_accounts,
                      color: Colors.orange,
                      isSelected: role == 'manager',
                      onTap: () => setSheetState(() => role = 'manager'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRoleSelector(
                      label: 'ADMIN',
                      icon: Icons.security,
                      color: Colors.red,
                      isSelected: role == 'admin',
                      onTap: () => setSheetState(() {
                        role = 'admin';
                        selectedBranchId = null; // Admins don't belong to a branch
                      }),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- BRANCH SELECTOR (Only if not Admin) ---
              if (role != 'admin') ...[
                const Text("Assign Branch", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedBranchId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: const Icon(Icons.store, color: Colors.indigo),
                  ),
                  hint: const Text("Select a Branch"),
                  items: _branches.map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(b.branchName),
                  )).toList(),
                  onChanged: (val) => setSheetState(() => selectedBranchId = val),
                ),
                const SizedBox(height: 24),
              ],

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username and Password required')));
                      return;
                    }
                    // Validate Branch selection for non-admins
                    if (role != 'admin' && selectedBranchId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Branch')));
                      return;
                    }

                    Navigator.pop(context);
                    _createUser(usernameController.text, passwordController.text, role, selectedBranchId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser(String username, String password, String role, int? branchId) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.createStaff(
          username: username,
          password: password,
          role: role,
          branchId: branchId // <--- Pass the ID
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully!'), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  // ... (existing _deleteUser and _changePassword methods remain the same) ...
  Future<void> _deleteUser(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('DELETE')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteStaff(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted.')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword(int id, String username) async {
    final passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password for $username'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) return;
              Navigator.pop(context);
              try {
                await _apiService.changeStaffPassword(userId: id, newPassword: passwordController.text);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Staff')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text("New User"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isAdmin = user.role == 'admin';
          final isManager = user.role == 'manager';

          // Find branch name for this user
          String branchName = 'Main';
          if (user.branchId != null) {
            final b = _branches.firstWhere((b) => b.id == user.branchId, orElse: () => Branch(id: 0, branchName: 'Unknown', branchCode: '', isActive: 1));
            if (b.id != 0) branchName = b.branchName;
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: isAdmin ? Colors.red.shade100 : (isManager ? Colors.orange.shade100 : Colors.blue.shade100),
                child: Icon(
                    isAdmin ? Icons.security : (isManager ? Icons.manage_accounts : Icons.person),
                    color: isAdmin ? Colors.red : (isManager ? Colors.orange : Colors.blue)
                ),
              ),
              title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                              color: isAdmin ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 10
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Show Branch Badge if not Admin
                      if (!isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade400)
                          ),
                          child: Text(
                            branchName,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'password') _changePassword(user.id, user.username);
                  if (value == 'delete') _deleteUser(user.id);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'password',
                    child: ListTile(
                      leading: Icon(Icons.key, color: Colors.orange),
                      title: Text('Reset Password'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete User'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}