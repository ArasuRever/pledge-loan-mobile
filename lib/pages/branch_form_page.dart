import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/branch_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class BranchFormPage extends StatefulWidget {
  final Branch? branch; // null = Create Mode
  const BranchFormPage({super.key, this.branch});

  @override
  State<BranchFormPage> createState() => _BranchFormPageState();
}

class _BranchFormPageState extends State<BranchFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _licenseCtrl;
  bool _isActive = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.branch?.branchName ?? '');
    _codeCtrl = TextEditingController(text: widget.branch?.branchCode ?? '');
    _phoneCtrl = TextEditingController(text: widget.branch?.phoneNumber ?? '');
    _addressCtrl = TextEditingController(text: widget.branch?.address ?? '');
    _licenseCtrl = TextEditingController(text: widget.branch?.licenseNumber ?? '');
    _isActive = widget.branch?.isActive == 1; // Default true for new
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final data = {
        'branch_name': _nameCtrl.text,
        'branch_code': _codeCtrl.text,
        'phone_number': _phoneCtrl.text,
        'address': _addressCtrl.text,
        'license_number': _licenseCtrl.text,
        'is_active': _isActive ? 1 : 0, // Ensure int is sent
      };

      if (widget.branch == null) {
        await _apiService.createBranch(data);
      } else {
        await _apiService.updateBranch(widget.branch!.id, data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch saved successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.branch != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Branch' : 'Add New Branch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: 'Branch Code (e.g. SLM)', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(labelText: 'License Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              if (isEdit)
                SwitchListTile(
                  title: const Text("Active Status"),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Branch", style: TextStyle(fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}