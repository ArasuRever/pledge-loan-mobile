// lib/pages/edit_loan_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:intl/intl.dart'; // <-- 1. IMPORT THE NEW PACKAGE

class EditLoanPage extends StatefulWidget {
  final LoanDetail loanDetail;

  const EditLoanPage({super.key, required this.loanDetail});

  @override
  State<EditLoanPage> createState() => _EditLoanPageState();
}

class _EditLoanPageState extends State<EditLoanPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Form field controllers
  late TextEditingController _bookLoanNumberController;
  late TextEditingController _interestRateController;
  late TextEditingController _descriptionController;
  late TextEditingController _qualityController;
  late TextEditingController _weightController;

  // --- 2. ADD CONTROLLERS AND STATE FOR DATES ---
  late TextEditingController _pledgeDateController;
  late TextEditingController _dueDateController;
  late DateTime _selectedPledgeDate;
  late DateTime _selectedDueDate;

  late String _selectedItemType;
  final List<String> _itemTypeOptions = ['gold', 'silver', 'gold+silver'];
  final List<String> _interestRateOptions = [
    '1.0', '1.5', '2.0', '2.5', '3.0', '3.5', '4.0'
  ];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill all controllers
    final loan = widget.loanDetail;
    _bookLoanNumberController = TextEditingController(text: loan.bookLoanNumber);
    _interestRateController = TextEditingController(text: loan.interestRate);
    _descriptionController = TextEditingController(text: loan.description);
    _qualityController = TextEditingController(text: loan.quality);
    _weightController = TextEditingController(text: loan.weight);

    _selectedItemType = _itemTypeOptions.contains(loan.itemType)
        ? loan.itemType!
        : 'gold';

    // --- 3. INITIALIZE DATE VALUES ---
    try {
      _selectedPledgeDate = DateTime.parse(loan.pledgeDate);
      _selectedDueDate = DateTime.parse(loan.dueDate);
    } catch (e) {
      _selectedPledgeDate = DateTime.now();
      _selectedDueDate = DateTime.now().add(const Duration(days: 30));
    }
    _pledgeDateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(_selectedPledgeDate)
    );
    _dueDateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(_selectedDueDate)
    );
  }

  // --- 4. HELPER FUNCTION TO SHOW DATE PICKER ---
  Future<void> _selectDate(BuildContext context, bool isPledgeDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPledgeDate ? _selectedPledgeDate : _selectedDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isPledgeDate) {
          _selectedPledgeDate = picked;
          _pledgeDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _selectedDueDate = picked;
          _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // --- 5. ADD DATES TO THE DATA MAP ---
      final Map<String, String> loanData = {
        'book_loan_number': _bookLoanNumberController.text,
        'interest_rate': _interestRateController.text,
        'item_type': _selectedItemType,
        'description': _descriptionController.text,
        'quality': _qualityController.text,
        'weight': _weightController.text,
        'pledge_date': _pledgeDateController.text, // Add pledge date
        'due_date': _dueDateController.text,       // Add due date
      };

      await _apiService.updateLoan(
        loanId: widget.loanDetail.id,
        loanData: loanData,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Pop and signal refresh
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _bookLoanNumberController.dispose();
    _interestRateController.dispose();
    _descriptionController.dispose();
    _qualityController.dispose();
    _weightController.dispose();
    _pledgeDateController.dispose(); // Dispose new controllers
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Loan #${widget.loanDetail.id}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Editing Loan for ${widget.loanDetail.customerName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _bookLoanNumberController,
              decoration: const InputDecoration(
                labelText: 'Book Loan Number',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
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
              validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) ? 'Invalid rate' : null,
            ),

            // --- 6. ADD DATE FIELDS TO THE UI ---
            const SizedBox(height: 16),
            TextFormField(
              controller: _pledgeDateController,
              decoration: const InputDecoration(
                labelText: 'Pledge Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true, // Makes field tappable but not editable
              onTap: () => _selectDate(context, true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dueDateController,
              decoration: const InputDecoration(
                labelText: 'Due Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectDate(context, false),
            ),
            // --- END OF NEW DATE FIELDS ---

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
              validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Item Description',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
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
                labelText: 'Quality',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitUpdate,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}