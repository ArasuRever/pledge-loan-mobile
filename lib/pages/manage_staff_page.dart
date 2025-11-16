// lib/pages/manage_staff_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/user_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class ManageStaffPage extends StatefulWidget {
  const ManageStaffPage({super.key});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  late Future<List<User>> _staffFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _loadStaff() {
    setState(() {
      _staffFuture = _apiService.getStaff();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- DIALOG FOR CREATING A NEW STAFF USER ---
  void _showCreateStaffDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Staff User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _apiService.createStaff(
                      username: usernameController.text,
                      password: passwordController.text,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    _showSnackBar('Staff created successfully');
                    _loadStaff(); // Refresh the list
                  } catch (e) {
                    _showSnackBar(e.toString(), isError: true);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG FOR CHANGING A USER'S PASSWORD ---
  void _showChangePasswordDialog(User user) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Change Password for ${user.username}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
              validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _apiService.changeStaffPassword(
                      userId: user.id,
                      newPassword: passwordController.text,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    _showSnackBar('Password updated successfully');
                  } catch (e) {
                    _showSnackBar(e.toString(), isError: true);
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG FOR DELETING A STAFF USER ---
  void _showDeleteConfirmDialog(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete ${user.username}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await _apiService.deleteStaff(user.id);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _showSnackBar('User deleted successfully');
                  _loadStaff(); // Refresh the list
                } catch (e) {
                  _showSnackBar(e.toString(), isError: true);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
      ),
      body: FutureBuilder<List<User>>(
        future: _staffFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                // --- 3. FIX: Replaced 'shield_person' with 'admin_panel_settings' ---
                leading: Icon(user.role == 'admin' ? Icons.admin_panel_settings : Icons.person),
                title: Text(user.username),
                subtitle: Text(user.role),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'password') {
                      _showChangePasswordDialog(user);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'password',
                      child: Text('Change Password'),
                    ),
                    if (user.role == 'staff') // Admins can't be deleted
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete User', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateStaffDialog,
        tooltip: 'Add Staff',
        child: const Icon(Icons.add),
      ),
    );
  }
}