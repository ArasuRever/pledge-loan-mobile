// lib/pages/edit_loan_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart'; // Import Transaction Model
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class EditLoanPage extends StatefulWidget {
  final LoanDetail loanDetail;

  const EditLoanPage({super.key, required this.loanDetail});

  @override
  State<EditLoanPage> createState() => _EditLoanPageState();
}

class _EditLoanPageState extends State<EditLoanPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // ... (Existing Controllers: _bookLoanNumberController, etc.) ...
  late TextEditingController _bookLoanNumberController;
  late TextEditingController _interestRateController;
  late TextEditingController _descriptionController;
  late TextEditingController _qualityController;
  late TextEditingController _grossWeightController;
  late TextEditingController _netWeightController;
  late TextEditingController _purityController;
  late TextEditingController _appraisedValueController;

  // Date controllers
  late TextEditingController _pledgeDateController;
  late TextEditingController _dueDateController;
  late DateTime _selectedPledgeDate;
  late DateTime _selectedDueDate;

  late String _selectedItemType;
  final List<String> _itemTypeOptions = ['gold', 'silver', 'brass', 'electronic', 'vehicle', 'other'];

  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;

  // --- NEW: Transaction State ---
  List<Transaction> _transactions = [];
  bool _isLoadingTxs = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _fetchTransactions(); // <--- Fetch on init
  }

  void _initializeForm() {
    final loan = widget.loanDetail;
    _bookLoanNumberController = TextEditingController(text: loan.bookLoanNumber);
    _interestRateController = TextEditingController(text: loan.interestRate);
    _descriptionController = TextEditingController(text: loan.description);
    _qualityController = TextEditingController(text: loan.quality);
    _grossWeightController = TextEditingController(text: loan.grossWeight ?? loan.weight);
    _netWeightController = TextEditingController(text: loan.netWeight);
    _purityController = TextEditingController(text: loan.purity);
    _appraisedValueController = TextEditingController(text: loan.appraisedValue);
    _selectedItemType = _itemTypeOptions.contains(loan.itemType) ? loan.itemType! : 'gold';

    try {
      _selectedPledgeDate = DateTime.parse(loan.pledgeDate);
      _selectedDueDate = DateTime.parse(loan.dueDate);
    } catch (e) {
      _selectedPledgeDate = DateTime.now();
      _selectedDueDate = DateTime.now().add(const Duration(days: 30));
    }
    _pledgeDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedPledgeDate));
    _dueDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDueDate));
  }

  Future<void> _fetchTransactions() async {
    try {
      final txs = await _apiService.getLoanTransactions(widget.loanDetail.id);
      if (mounted) {
        setState(() {
          _transactions = txs;
          _isLoadingTxs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTxs = false);
      print("Error fetching transactions: $e");
    }
  }

  // --- NEW: Add Manual Transaction Dialog ---
  void _showAddTransactionDialog() {
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String type = 'interest';
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Manual Log", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add past/missing payments. Logic handles interest split automatically.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                // Date Picker
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setStateDialog(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Type Dropdown
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                  items: const [
                    DropdownMenuItem(value: 'interest', child: Text('Interest')),
                    DropdownMenuItem(value: 'principal', child: Text('Principal')),
                    DropdownMenuItem(value: 'settlement', child: Text('Settlement')),
                  ],
                  onChanged: (v) => setStateDialog(() => type = v!),
                ),
                const SizedBox(height: 12),
                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: submitting ? null : () async {
                  if (amountCtrl.text.isEmpty) return;
                  setStateDialog(() => submitting = true);
                  try {
                    await _apiService.addPayment(
                      loanId: widget.loanDetail.id,
                      amount: amountCtrl.text,
                      paymentType: type,
                      customDate: DateFormat('yyyy-MM-dd').format(selectedDate), // Sending Backdate
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchTransactions(); // Refresh list
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction Logged")));
                    }
                  } catch (e) {
                    setStateDialog(() => submitting = false);
                    // Use a Builder to show SnackBar in the dialog context or parent
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                  }
                },
                child: submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Add"),
              )
            ],
          );
        },
      ),
    );
  }

  // ... (Existing Methods: _pickImage, _showImageSourceActionSheet, _selectDate, _submitUpdate, _onGrossWeightChanged, dispose) ...
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () { _pickImage(ImageSource.gallery); Navigator.of(context).pop(); }),
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { _pickImage(ImageSource.camera); Navigator.of(context).pop(); }),
        ]),
      ),
    );
  }

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
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final Map<String, String> loanData = {
        'book_loan_number': _bookLoanNumberController.text,
        'interest_rate': _interestRateController.text,
        'item_type': _selectedItemType,
        'description': _descriptionController.text,
        'quality': _qualityController.text,
        'gross_weight': _grossWeightController.text,
        'net_weight': _netWeightController.text,
        'purity': _purityController.text,
        'appraised_value': _appraisedValueController.text,
        'pledge_date': _pledgeDateController.text,
        'due_date': _dueDateController.text,
      };
      await _apiService.updateLoan(loanId: widget.loanDetail.id, loanData: loanData, imageFile: _imageFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan updated!')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  void _onGrossWeightChanged(String val) {
    if (_netWeightController.text.isEmpty) _netWeightController.text = val;
  }

  @override
  void dispose() {
    _bookLoanNumberController.dispose();
    _interestRateController.dispose();
    _descriptionController.dispose();
    _qualityController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    _purityController.dispose();
    _appraisedValueController.dispose();
    _pledgeDateController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Loan #${widget.loanDetail.id}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- 1. PHOTO SECTION ---
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Container(
                height: 180, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : (widget.loanDetail.itemImageDataUrl != null
                      ? Image.network(widget.loanDetail.itemImageDataUrl!, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text("Tap to change photo", style: TextStyle(color: Colors.grey))])),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. LOAN TERMS ---
            const Text('Loan Terms', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            TextFormField(controller: _bookLoanNumberController, decoration: const InputDecoration(labelText: 'Book Loan Number', border: OutlineInputBorder()), validator: (value) => (value == null || value.isEmpty) ? 'Required' : null),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _interestRateController, decoration: const InputDecoration(labelText: 'Interest Rate (%)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 10), Expanded(child: Container()),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _pledgeDateController, decoration: const InputDecoration(labelText: 'Pledge Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today, size: 18)), readOnly: true, onTap: () => _selectDate(context, true))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _dueDateController, decoration: const InputDecoration(labelText: 'Due Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.event, size: 18)), readOnly: true, onTap: () => _selectDate(context, false))),
            ]),

            const SizedBox(height: 24),
            // --- 3. ITEM DETAILS ---
            const Text('Item Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: _selectedItemType, decoration: const InputDecoration(labelText: 'Item Type', border: OutlineInputBorder()), items: _itemTypeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(), onChanged: (val) => setState(() => _selectedItemType = val!)),
            const SizedBox(height: 16),
            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 2, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _grossWeightController, decoration: const InputDecoration(labelText: 'Gross Wt (g)', border: OutlineInputBorder()), keyboardType: TextInputType.numberWithOptions(decimal: true), onChanged: _onGrossWeightChanged)),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _netWeightController, decoration: const InputDecoration(labelText: 'Net Wt (g)', border: OutlineInputBorder()), keyboardType: TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _purityController, decoration: const InputDecoration(labelText: 'Purity', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _appraisedValueController, decoration: const InputDecoration(labelText: 'Appraised Val', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _qualityController, decoration: const InputDecoration(labelText: 'Quality / Remarks', border: OutlineInputBorder())),

            const SizedBox(height: 32),
            if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _submitUpdate, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(fontSize: 18)))),

            const SizedBox(height: 40),
            const Divider(thickness: 2),

            // --- 4. TRANSACTION LOG ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Transaction Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                TextButton.icon(
                  onPressed: _showAddTransactionDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text("Manual Log"),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue[800]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingTxs
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : _transactions.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No transactions recorded.", style: TextStyle(color: Colors.grey))))
                : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final tx = _transactions[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: tx.color.withOpacity(0.1),
                    child: Icon(tx.icon, color: tx.color, size: 18),
                  ),
                  title: Text(tx.paymentType.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(tx.formattedDate),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tx.formattedAmount, style: TextStyle(color: tx.color, fontWeight: FontWeight.bold)),
                      Text(tx.changedByUsername ?? 'sys', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}