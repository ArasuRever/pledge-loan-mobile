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

  // Phone Controllers (Up to 3)
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _phone3Controller;

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
    _phone1Controller = TextEditingController();
    _phone2Controller = TextEditingController();
    _phone3Controller = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _apiService.getBusinessSettings();
      _nameController.text = settings.businessName;
      _addressController.text = settings.address;
      _licenseController.text = settings.licenseNumber;
      _currentLogoUrl = settings.logoUrl;

      // Split phone numbers (Backend stores as comma separated string)
      List<String> phones = settings.phoneNumber.split(',').map((s) => s.trim()).toList();
      if (phones.isNotEmpty) _phone1Controller.text = phones[0];
      if (phones.length > 1) _phone2Controller.text = phones[1];
      if (phones.length > 2) _phone3Controller.text = phones[2];

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
    } finally {
      setState(() => _isLoading = false);
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
    List<String> validPhones = [
      _phone1Controller.text,
      _phone2Controller.text,
      _phone3Controller.text
    ].where((s) => s.isNotEmpty).toList();

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
        Navigator.pop(context, true); // Return true to indicate update
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
        // Handle Data URL
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
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Business Settings")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _getLogoProvider(),
                    child: _getLogoProvider() == null
                        ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(child: Text("Tap to update Logo", style: TextStyle(color: Colors.grey))),

              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Business Name", prefixIcon: Icon(Icons.store)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Address", prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: "License Number", prefixIcon: Icon(Icons.badge)),
              ),

              const SizedBox(height: 25),
              const Text("Contact Numbers (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              TextFormField(
                controller: _phone1Controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Mobile 1 (Primary)", prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone2Controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Mobile 2", prefixIcon: Icon(Icons.phone_android)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone3Controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Mobile 3", prefixIcon: Icon(Icons.phone_android)),
              ),

              const SizedBox(height: 40),
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
            ],
          ),
        ),
      ),
    );
  }
}