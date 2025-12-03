import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class LoanFormPage extends StatefulWidget {
  final int customerId;
  final String customerName;

  const LoanFormPage({
    super.key,
    required this.customerId,
    required this.customerName
  });

  @override
  _LoanFormPageState createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers ---
  final _bookLoanNumberController = TextEditingController();
  final _principalAmountController = TextEditingController();
  final _interestRateController = TextEditingController(text: '2.5'); // Default
  final _descriptionController = TextEditingController();
  final _qualityController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _netWeightController = TextEditingController();
  final _purityController = TextEditingController();
  final _appraisedValueController = TextEditingController();

  // --- State Variables ---
  String _itemType = 'gold';
  bool _deductInterest = false;
  File? _imageFile;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // --- Handlers ---

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 70
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImagePickerOptions() {
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

  // Auto-fill Net Weight when Gross Weight is typed (if Net is empty)
  void _onGrossWeightChanged(String val) {
    if (_netWeightController.text.isEmpty) {
      _netWeightController.text = val;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Prepare Data
      Map<String, String> loanData = {
        'customer_id': widget.customerId.toString(),
        'book_loan_number': _bookLoanNumberController.text,
        'principal_amount': _principalAmountController.text,
        'interest_rate': _interestRateController.text,
        'item_type': _itemType,
        'description': _descriptionController.text,
        'quality': _qualityController.text,
        'gross_weight': _grossWeightController.text,
        'net_weight': _netWeightController.text,
        'purity': _purityController.text,
        'appraised_value': _appraisedValueController.text,
        'deductFirstMonthInterest': _deductInterest.toString(),
      };

      try {
        await _apiService.createLoan(
          loanData: loanData,
          imageFile: _imageFile,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loan created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to refresh list
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
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Common interest rate options
    final interestOptions = ['1.0', '1.5', '1.8', '2.0', '2.25', '2.5', '3.0'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Pledge Loan'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.indigo),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.customerName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- SECTION 1: LOAN TERMS ---
              const Text(
                  'Loan Terms',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bookLoanNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Book Loan #',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bookmark_border),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _principalAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Principal (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Editable Interest Rate + Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editable Text Field
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _interestRateController,
                      decoration: const InputDecoration(
                        labelText: 'Interest %',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 2.5',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? 'Req' : null,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Popup Selector
                  PopupMenuButton<String>(
                    icon: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                    onSelected: (value) {
                      setState(() {
                        _interestRateController.text = value;
                      });
                    },
                    itemBuilder: (context) => interestOptions.map((rate) {
                      return PopupMenuItem<String>(
                        value: rate,
                        child: Text("$rate%"),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Deduct Interest Checkbox
              CheckboxListTile(
                title: const Text("Deduct 1st Month Interest now?", style: TextStyle(fontSize: 13)),
                value: _deductInterest,
                onChanged: (val) => setState(() => _deductInterest = val!),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const Divider(height: 30),

              // --- SECTION 2: ITEM DETAILS ---
              const Text(
                  'Pledged Item Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _itemType,
                decoration: const InputDecoration(
                  labelText: 'Item Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: <String>[
                  'gold', 'silver', 'brass', 'electronic', 'vehicle', 'other'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _itemType = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
                validator: (val) => val!.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 16),

              // Weights
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grossWeightController,
                      decoration: const InputDecoration(
                          labelText: 'Gross Wt (g)',
                          border: OutlineInputBorder()
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onGrossWeightChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _netWeightController,
                      decoration: const InputDecoration(
                          labelText: 'Net Wt (g)',
                          border: OutlineInputBorder()
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Purity & Value
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purityController,
                      decoration: const InputDecoration(
                          labelText: 'Purity',
                          border: OutlineInputBorder(),
                          hintText: '916 KDM'
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _appraisedValueController,
                      decoration: const InputDecoration(
                          labelText: 'Appraised Val (₹)',
                          border: OutlineInputBorder()
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _qualityController,
                decoration: const InputDecoration(
                  labelText: 'Quality / Remarks',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // --- SECTION 3: PHOTO ---
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade600),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add Item Photo',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              if (_imageFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _imageFile = null),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Remove Photo", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // --- SUBMIT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                      'CREATE PLEDGE LOAN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bookLoanNumberController.dispose();
    _principalAmountController.dispose();
    _interestRateController.dispose();
    _descriptionController.dispose();
    _qualityController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    _purityController.dispose();
    _appraisedValueController.dispose();
    super.dispose();
  }
}