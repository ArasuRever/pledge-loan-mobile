// lib/widgets/settle_loan_dialog.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class SettleLoanDialog extends StatefulWidget {
  final int loanId;
  final VoidCallback onSuccess; // This function will be called on success

  const SettleLoanDialog({
    super.key,
    required this.loanId,
    required this.onSuccess,
  });

  @override
  State<SettleLoanDialog> createState() => _SettleLoanDialogState();
}

class _SettleLoanDialogState extends State<SettleLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _discountController = TextEditingController(text: '0');

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitSettle() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form is invalid
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.settleLoan(
        loanId: widget.loanId,
        discountAmount: _discountController.text,
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settle Loan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will calculate all outstanding interest and principal and close the loan. Enter any discount amount below.',
              ),
              const SizedBox(height: 24),
              // Amount Field
              TextFormField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Discount Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter 0 or a discount amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) < 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
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
          onPressed: _isLoading ? null : _submitSettle,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Text('Settle', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}