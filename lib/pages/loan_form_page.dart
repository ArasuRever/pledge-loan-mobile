// lib/pages/loan_form_page.dart
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For ImageSource
import 'package:permission_handler/permission_handler.dart';
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class LoanFormPage extends StatefulWidget {
  final Customer customer;
  const LoanFormPage({super.key, required this.customer});

  @override
  State<LoanFormPage> createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Form field controllers
  final _bookLoanNumberController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestRateController = TextEditingController(text: '2.5');
  final _descriptionController = TextEditingController();
  final _qualityController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedItemType = 'gold';
  final List<String> _itemTypeOptions = ['gold', 'silver', 'gold+silver'];
  final List<String> _interestRateOptions = [
    '1.0', '1.5', '2.0', '2.5', '3.0', '3.5', '4.0'
  ];

  bool _deductFirstMonthInterest = false;
  bool _isLoading = false;

  // --- 1. NEW STATE FOR IMAGE ---
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // --- 2. NEW FUNCTION TO GET IMAGE ---
  Future<void> _pickImage(ImageSource source) async {
    // Check permissions
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      // Use .photos for modern Android/iOS
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(source == ImageSource.camera ? 'Camera Permission' : 'Gallery Permission'),
          content: Text('Permission was permanently denied. Please go to app settings to enable it.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            source == ImageSource.camera
                ? 'Camera permission denied.'
                : 'Gallery permission denied.'
        )),
      );
    }
  }

  Future<void> _submitLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      final Map<String, String> loanData = {
        'customer_id': widget.customer.id.toString(),
        'book_loan_number': _bookLoanNumberController.text,
        'principal_amount': _principalController.text,
        'interest_rate': _interestRateController.text,
        'item_type': _selectedItemType,
        'description': _descriptionController.text,
        'quality': _qualityController.text,
        'weight': _weightController.text,
        'deductFirstMonthInterest': _deductFirstMonthInterest.toString(),
      };

      // --- 3. PASS IMAGE TO API SERVICE ---
      await _apiService.createLoan(
        loanData: loanData,
        imageFile: _imageFile, // Pass the file
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _bookLoanNumberController.dispose();
    _principalController.dispose();
    _interestRateController.dispose();
    _descriptionController.dispose();
    _qualityController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Loan for ${widget.customer.name}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- ALL YOUR ORIGINAL, WORKING FORM FIELDS ---
            TextFormField(
              controller: _bookLoanNumberController,
              decoration: const InputDecoration(
                labelText: 'Book Loan Number',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Please enter a book loan number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _principalController,
              decoration: const InputDecoration(
                labelText: 'Principal Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) ? 'Please enter a valid principal amount' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _interestRateController,
              decoration: InputDecoration(
                labelText: 'Monthly Interest Rate (%)',
                border: const OutlineInputBorder(),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (String value) => setState(() => _interestRateController.text = value),
                  itemBuilder: (BuildContext context) => _interestRateOptions
                      .map((String value) => PopupMenuItem<String>(value: value, child: Text('$value%')))
                      .toList(),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) ? 'Please enter a valid interest rate' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedItemType,
              decoration: const InputDecoration(
                labelText: 'Item Type',
                border: OutlineInputBorder(),
              ),
              items: _itemTypeOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value[0].toUpperCase() + value.substring(1)),
                );
              }).toList(),
              onChanged: (String? newValue) => setState(() => _selectedItemType = newValue!),
              validator: (value) => (value == null || value.isEmpty) ? 'Please select an item type' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Item Description (e.g., "Ring", "Chain")',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Please enter an item description' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (grams)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qualityController,
              decoration: const InputDecoration(
                labelText: 'Quality (e.g., "916", "Silver")',
                border: OutlineInputBorder(),
              ),
            ),
            // --- END OF ORIGINAL FORM FIELDS ---

            const SizedBox(height: 16),

            // --- 4. NEW IMAGE PICKER UI ---
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Text('Pledged Item Photo (Optional)'),
                  const SizedBox(height: 8),
                  if (_imageFile != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.file(
                            _imageFile!,
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _imageFile = null),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // --- END NEW IMAGE UI ---

            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text("Deduct first month's interest"),
              value: _deductFirstMonthInterest,
              onChanged: (bool? value) {
                setState(() {
                  _deductFirstMonthInterest = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitLoan,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Loan'),
            ),
          ],
        ),
      ),
    );
  }
}