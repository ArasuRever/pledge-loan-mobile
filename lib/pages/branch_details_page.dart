import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/branch_model.dart';
import 'package:pledge_loan_mobile/models/user_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/branch_form_page.dart';

class BranchDetailsPage extends StatefulWidget {
  final Branch branch;
  const BranchDetailsPage({super.key, required this.branch});

  @override
  State<BranchDetailsPage> createState() => _BranchDetailsPageState();
}

class _BranchDetailsPageState extends State<BranchDetailsPage> {
  final ApiService _apiService = ApiService();
  late Branch _branch;
  List<User> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _branch = widget.branch; // Init with passed branch
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Refresh Branch Data (in case of edits)
      final branches = await _apiService.getBranches();
      final updatedBranch = branches.firstWhere((b) => b.id == _branch.id, orElse: () => _branch);

      // 2. Fetch All Staff and Filter
      final allStaff = await _apiService.getStaff();
      final branchStaff = allStaff.where((u) => u.branchId == _branch.id).toList();

      setState(() {
        _branch = updatedBranch;
        _staff = branchStaff;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS ---

  void _editBranchMetadata() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BranchFormPage(branch: _branch)),
    );
    if (result == true) _fetchData();
  }

  Future<void> _deleteUser(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff?'),
        content: const Text('Are you sure you want to remove this user from the system?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('REMOVE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteStaff(userId);
      _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User removed.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _changePassword(User user) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password: ${user.username}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _apiService.changeStaffPassword(userId: user.id, newPassword: controller.text);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(User user) async {
    String selectedRole = user.role;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Role: ${user.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text("Staff"),
                value: "staff",
                groupValue: selectedRole,
                onChanged: (val) => setState(() => selectedRole = val!),
              ),
              RadioListTile<String>(
                title: const Text("Manager"),
                value: "manager",
                groupValue: selectedRole,
                onChanged: (val) => setState(() => selectedRole = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _apiService.updateStaff(user.id, {'role': selectedRole});
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: Text(_branch.branchName), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BRANCH META CARD ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.store, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_branch.branchName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(_branch.branchCode, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: _editBranchMetadata,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _InfoRow(icon: Icons.phone, value: _branch.phoneNumber),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.location_on, value: _branch.address),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.badge, value: _branch.licenseNumber, label: "License"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _branch.isActive == 1 ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _branch.isActive == 1 ? "Active" : "Inactive",
                            style: TextStyle(color: _branch.isActive == 1 ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text("Staff & Managers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const SizedBox(height: 12),

            // --- STAFF LIST ---
            if (_staff.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    const Text("No staff assigned yet", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _staff.length,
                itemBuilder: (context, index) {
                  final user = _staff[index];
                  final isManager = user.role == 'manager';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isManager ? Colors.orange.shade100 : Colors.blue.shade100,
                        child: Icon(isManager ? Icons.manage_accounts : Icons.person, color: isManager ? Colors.orange : Colors.blue),
                      ),
                      title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(user.role.toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'role') _changeRole(user);
                          if (action == 'pwd') _changePassword(user);
                          if (action == 'del') _deleteUser(user.id);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'role', child: Row(children: [Icon(Icons.admin_panel_settings, size: 18), SizedBox(width: 8), Text("Edit Role")])),
                          const PopupMenuItem(value: 'pwd', child: Row(children: [Icon(Icons.key, size: 18), SizedBox(width: 8), Text("Reset Password")])),
                          const PopupMenuItem(value: 'del', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Remove", style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String? value;
  final String? label;
  const _InfoRow({required this.icon, this.value, this.label});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label != null ? "$label: $value" : value!,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}