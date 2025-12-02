// lib/pages/business_settings_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/models/business_settings_model.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _licenseController;

  // Dynamic Phone List
  final List<TextEditingController> _phoneControllers = [];

  File? _logoFile;
  String? _currentLogoUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _licenseController = TextEditingController();
    // Start with at least one phone field
    _addPhoneField('');
    _loadSettings();
  }

  void _addPhoneField(String number) {
    if (_phoneControllers.length < 3) {
      _phoneControllers.add(TextEditingController(text: number));
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 3 phone numbers allowed")));
    }
  }

  void _removePhoneField(int index) {
    if (_phoneControllers.length > 1) {
      _phoneControllers[index].dispose();
      _phoneControllers.removeAt(index);
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _apiService.getBusinessSettings();
      _nameController.text = settings.businessName;
      _addressController.text = settings.address;
      _licenseController.text = settings.licenseNumber;
      _currentLogoUrl = settings.logoUrl;

      // Handle Phone Numbers
      if (settings.phoneNumber.isNotEmpty) {
        // Clear default empty field
        for (var c in _phoneControllers) c.dispose();
        _phoneControllers.clear();

        List<String> phones = settings.phoneNumber.split(',').map((s) => s.trim()).toList();
        for (String p in phones) {
          if (p.isNotEmpty) _phoneControllers.add(TextEditingController(text: p));
        }
      }
      // Ensure at least one field exists
      if (_phoneControllers.isEmpty) _addPhoneField('');

    } catch (e) {
      // Fail silently or show toast, start with defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Combine phones
    List<String> validPhones = _phoneControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String combinedPhone = validPhones.join(', ');

    try {
      await _apiService.updateBusinessSettings(
        businessName: _nameController.text,
        address: _addressController.text,
        phoneNumber: combinedPhone,
        licenseNumber: _licenseController.text,
        logoFile: _logoFile,
        existingLogoUrl: _currentLogoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Updated Successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider? _getLogoProvider() {
    if (_logoFile != null) return FileImage(_logoFile!);
    if (_currentLogoUrl != null && _currentLogoUrl!.isNotEmpty) {
      try {
        if (_currentLogoUrl!.startsWith('data:')) {
          final base64Str = _currentLogoUrl!.split(',')[1];
          return MemoryImage(base64Decode(base64Str));
        }
        return NetworkImage(_currentLogoUrl!);
      } catch (_) {}
    }
    return null;
  }

  @override
  void dispose() {
    for (var c in _phoneControllers) c.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Business Settings")),
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- LOGO CARD ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          height: 120, width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            image: _getLogoProvider() != null ? DecorationImage(image: _getLogoProvider()!, fit: BoxFit.contain) : null,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _getLogoProvider() == null
                              ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text("Tap to change Logo", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- IDENTITY INFO ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Company Identity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
                      const Divider(),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Business Name", prefixIcon: Icon(Icons.store)),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licenseController,
                        decoration: const InputDecoration(labelText: "License Number", prefixIcon: Icon(Icons.badge)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- CONTACT INFO (Dynamic Phones) ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Contact Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
                          if (_phoneControllers.length < 3)
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              tooltip: "Add another number",
                              onPressed: () => _addPhoneField(''),
                            )
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: "Address", prefixIcon: Icon(Icons.location_on)),
                      ),
                      const SizedBox(height: 20),
                      const Text("Mobile Numbers", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),

                      // Dynamic Phone Fields
                      ..._phoneControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        TextEditingController controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: idx == 0 ? "Primary Mobile" : "Mobile ${idx + 1}",
                                    prefixIcon: const Icon(Icons.phone_android),
                                  ),
                                ),
                              ),
                              if (idx > 0)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removePhoneField(idx),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE SETTINGS"),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}