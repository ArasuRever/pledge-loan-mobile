// lib/pages/loan_form_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class LoanFormPage extends StatefulWidget {
  final int customerId;
  final String customerName;

  const LoanFormPage(
      {super.key, required this.customerId, required this.customerName});

  @override
  _LoanFormPageState createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _bookLoanNumberController = TextEditingController();
  final _principalAmountController = TextEditingController();
  final _interestRateController = TextEditingController(text: '2.5');
  final _descriptionController = TextEditingController();
  final _qualityController = TextEditingController();

  // --- NEW WEIGHT CONTROLLERS ---
  final _grossWeightController = TextEditingController();
  final _netWeightController = TextEditingController();
  final _purityController = TextEditingController();
  final _appraisedValueController = TextEditingController();

  String _itemType = 'gold';
  bool _deductInterest = false;

  File? _imageFile;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      Map<String, String> loanData = {
        'customer_id': widget.customerId.toString(),
        'book_loan_number': _bookLoanNumberController.text,
        'principal_amount': _principalAmountController.text,
        'interest_rate': _interestRateController.text,
        'item_type': _itemType,
        'description': _descriptionController.text,
        'quality': _qualityController.text,
        // --- PASS NEW FIELDS ---
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
            const SnackBar(content: Text('Loan created successfully!')),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Helper to auto-fill net weight
  void _onGrossWeightChanged(String val) {
    if (_netWeightController.text.isEmpty) {
      _netWeightController.text = val;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Pledge Loan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${widget.customerName}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo)),
              const SizedBox(height: 20),

              // --- LOAN DETAILS ---
              const Text('Loan Terms', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bookLoanNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Book Loan #',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _principalAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Principal (₹)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _interestRateController.text,
                      decoration: const InputDecoration(labelText: 'Interest Rate', border: OutlineInputBorder()),
                      items: ['1.0', '1.5', '2.0', '2.25', '2.5', '3.0']
                          .map((e) => DropdownMenuItem(value: e, child: Text('$e%')))
                          .toList(),
                      onChanged: (val) => setState(() => _interestRateController.text = val!),
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text("Deduct 1st Month?", style: TextStyle(fontSize: 12)),
                      value: _deductInterest,
                      onChanged: (val) => setState(() => _deductInterest = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- ITEM DETAILS ---
              const Text('Pledged Item', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _itemType,
                decoration: const InputDecoration(
                  labelText: 'Item Type',
                  border: OutlineInputBorder(),
                ),
                items: <String>[
                  'gold',
                  'silver',
                  'brass',
                  'electronic',
                  'vehicle',
                  'other'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _itemType = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) =>
                value!.isEmpty ? 'Please enter description' : null,
              ),

              const SizedBox(height: 16),

              // --- WEIGHTS & PURITY ---
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grossWeightController,
                      decoration: const InputDecoration(labelText: 'Gross Wt (g)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onGrossWeightChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _netWeightController,
                      decoration: const InputDecoration(labelText: 'Net Wt (g)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purityController,
                      decoration: const InputDecoration(labelText: 'Purity', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _appraisedValueController,
                      decoration: const InputDecoration(labelText: 'Appraised Val (₹)', border: OutlineInputBorder()),
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

              // --- PHOTO ---
              GestureDetector(
                onTap: () {
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
                },
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 50, color: Colors.grey),
                        Text('Add Item Photo'),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Pledge', style: TextStyle(fontSize: 18)),
                ),
              ),
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