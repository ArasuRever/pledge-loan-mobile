import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/branch_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/pages/branch_form_page.dart';
import 'package:pledge_loan_mobile/pages/branch_details_page.dart'; // Ensure this is imported

class ManageBranchesPage extends StatefulWidget {
  const ManageBranchesPage({super.key});

  @override
  State<ManageBranchesPage> createState() => _ManageBranchesPageState();
}

class _ManageBranchesPageState extends State<ManageBranchesPage> {
  final ApiService _apiService = ApiService();
  List<Branch> _branches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getBranches();
      if (mounted) {
        setState(() => _branches = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Navigate to Create Form (Empty Branch)
  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BranchFormPage(branch: null)),
    );
    if (result == true) {
      _fetchBranches();
    }
  }

  // Navigate to Details Page (View Staff & Metadata)
  void _navigateToDetails(Branch branch) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BranchDetailsPage(branch: branch)),
    );
    _fetchBranches(); // Refresh list when returning in case details were updated
  }

  Future<void> _toggleStatus(Branch branch) async {
    try {
      // Toggle logic: 1 -> 0, 0 -> 1
      final newStatus = branch.isActive == 1 ? 0 : 1;

      // We need to send the full payload to update
      final Map<String, dynamic> data = branch.toJson();
      data['is_active'] = newStatus;

      await _apiService.updateBranch(branch.id, data);
      _fetchBranches(); // Refresh UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Branches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        label: const Text("Add Branch"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _branches.length,
        itemBuilder: (context, index) {
          final branch = _branches[index];
          final isActive = branch.isActive == 1;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _navigateToDetails(branch), // Tap to view Staff/Details
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(Icons.store, color: isActive ? Colors.green : Colors.red),
                  ),
                  title: Text(branch.branchName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${branch.branchCode} • ${branch.phoneNumber ?? 'No Phone'}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Status Toggle
                      Switch(
                        value: isActive,
                        activeColor: Colors.green,
                        onChanged: (val) => _toggleStatus(branch),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}