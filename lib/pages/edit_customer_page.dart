import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';

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
    // Pre-fill data
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
    _addressController = TextEditingController(text: widget.customer.address);
    _idTypeController = TextEditingController(text: widget.customer.idProofType ?? 'Aadhaar');
    _idNumberController = TextEditingController(text: widget.customer.idProofNumber);
    _nomineeNameController = TextEditingController(text: widget.customer.nomineeName);
    _nomineeRelationController = TextEditingController(text: widget.customer.nomineeRelation);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Optimize size
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
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

  // Helper to handle existing Base64 images from DB
  ImageProvider? _getImageProvider(String? imageData) {
    if (imageData == null || imageData.isEmpty) return null;
    try {
      // Remove header if present (e.g., "data:image/jpeg;base64,")
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
          photoFile: _imageFile, // Passes file to ApiService (which uses field 'photo')
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer profile updated!'))
          );
          Navigator.pop(context, true); // Return true to refresh parent
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red)
          );
        }
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
              // --- Profile Picture Section ---
              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  // Logic: Show new file if picked, else show existing DB image, else show icon
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : _getImageProvider(widget.customer.imageUrl),
                  child: (_imageFile == null && (widget.customer.imageUrl == null || widget.customer.imageUrl!.isEmpty))
                      ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              const Text("Tap to change photo", style: TextStyle(color: Colors.blue, fontSize: 12)),

              const SizedBox(height: 24),

              // --- Basic Info ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person)
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone)
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home)
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: Text("KYC Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              const SizedBox(height: 10),

              // --- KYC ---
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _idTypeController.text.isNotEmpty ? _idTypeController.text : 'Aadhaar',
                      decoration: const InputDecoration(labelText: 'ID Type', border: OutlineInputBorder()),
                      items: ['Aadhaar', 'PAN', 'Voter ID', 'License', 'Ration Card']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nomineeNameController,
                      decoration: const InputDecoration(labelText: 'Nominee Name', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _nomineeRelationController,
                      decoration: const InputDecoration(labelText: 'Relation', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE CHANGES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}