// lib/pages/edit_customer_page.dart
import 'dart:io';
import 'dart:convert'; // Added import
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class EditCustomerPage extends StatefulWidget {
  final Customer customer;
  const EditCustomerPage({super.key, required this.customer});

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _idTypeController;
  late TextEditingController _idNumberController;
  late TextEditingController _nomineeNameController;
  late TextEditingController _nomineeRelationController;

  File? _imageFile;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
    _addressController = TextEditingController(text: widget.customer.address);
    _idTypeController = TextEditingController(text: widget.customer.idProofType ?? 'Aadhaar');
    _idNumberController = TextEditingController(text: widget.customer.idProofNumber);
    _nomineeNameController = TextEditingController(text: widget.customer.nomineeName);
    _nomineeRelationController = TextEditingController(text: widget.customer.nomineeRelation);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- FIX: Helper to handle Base64 Images ---
  ImageProvider? _getImageProvider(String? imageData) {
    if (imageData == null || imageData.isEmpty) return null;
    try {
      final cleanBase64 = imageData.contains(',') ? imageData.split(',')[1] : imageData;
      return MemoryImage(base64Decode(cleanBase64));
    } catch (e) {
      return null;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _apiService.updateCustomer(
          id: widget.customer.id,
          name: _nameController.text,
          phoneNumber: _phoneController.text,
          address: _addressController.text,
          idProofType: _idTypeController.text,
          idProofNumber: _idNumberController.text,
          nomineeName: _nomineeNameController.text,
          nomineeRelation: _nomineeRelationController.text,
          photoFile: _imageFile,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer updated!')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Customer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  // --- FIX: Logic to choose between New File, Existing Base64, or Icon ---
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : _getImageProvider(widget.customer.imageUrl),
                  child: (_imageFile == null && widget.customer.imageUrl == null)
                      ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text("Tap photo to change", style: TextStyle(color: Colors.grey, fontSize: 12)),

              const SizedBox(height: 20),
              // ... Rest of your form fields remain the same ...
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _idTypeController.text,
                      decoration: const InputDecoration(labelText: 'ID Type', border: OutlineInputBorder()),
                      items: ['Aadhaar', 'PAN', 'Voter ID', 'License', 'Ration Card'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _idTypeController.text = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _idNumberController,
                      decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomineeNameController,
                decoration: const InputDecoration(labelText: 'Nominee Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomineeRelationController,
                decoration: const InputDecoration(labelText: 'Relation', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Profile', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}