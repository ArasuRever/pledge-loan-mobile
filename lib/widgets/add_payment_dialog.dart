// lib/widgets/add_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class AddPaymentDialog extends StatefulWidget {
  final int loanId;
  final VoidCallback onSuccess; // This function will be called on success

  const AddPaymentDialog({
    super.key,
    required this.loanId,
    required this.onSuccess,
  });

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();
  // final _detailsController = TextEditingController(); // <-- FIX: Removed

  String _paymentType = 'interest'; // Default payment type
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form is invalid
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // --- FIX: Removed the 'details' parameter ---
      await _apiService.addPayment(
        loanId: widget.loanId,
        amount: _amountController.text,
        paymentType: _paymentType,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog on success
        widget.onSuccess(); // Call the refresh function
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    // _detailsController.dispose(); // <-- FIX: Removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Payment Type Radio Buttons
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Interest'),
                      value: 'interest',
                      groupValue: _paymentType,
                      onChanged: (value) => setState(() => _paymentType = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Principal'),
                      value: 'principal',
                      groupValue: _paymentType,
                      onChanged: (value) => setState(() => _paymentType = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              // --- FIX: Removed Details Field ---

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPayment,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Text('Submit'),
        ),
      ],
    );
  }
}