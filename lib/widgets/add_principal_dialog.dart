// lib/widgets/add_principal_dialog.dart
import 'package:flutter/material.dart'; // <-- THIS WAS THE FIX
import 'package:pledge_loan_mobile/services/api_service.dart';

class AddPrincipalDialog extends StatefulWidget {
  final int loanId;
  final VoidCallback onSuccess;

  const AddPrincipalDialog({
    super.key,
    required this.loanId,
    required this.onSuccess,
  });

  @override
  State<AddPrincipalDialog> createState() => _AddPrincipalDialogState();
}

class _AddPrincipalDialogState extends State<AddPrincipalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitAddPrincipal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.addPrincipal(
        loanId: widget.loanId,
        amount: _amountController.text,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        widget.onSuccess(); // Call refresh
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
      title: const Text('Add Principal (Disburse)'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will add more principal to the loan, increasing the total amount owed.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Additional Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid positive amount';
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
          onPressed: _isLoading ? null : _submitAddPrincipal,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Text('Disburse', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}