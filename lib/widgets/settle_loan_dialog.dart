// lib/widgets/settle_loan_dialog.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class SettleLoanDialog extends StatefulWidget {
  final int loanId;
  final double outstandingBalance; // <--- Received from parent
  final VoidCallback onSuccess;

  const SettleLoanDialog({
    super.key,
    required this.loanId,
    required this.outstandingBalance,
    required this.onSuccess,
  });

  @override
  State<SettleLoanDialog> createState() => _SettleLoanDialogState();
}

class _SettleLoanDialogState extends State<SettleLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  late TextEditingController _cashController;
  late TextEditingController _discountController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default: User pays full amount in cash, 0 discount
    _cashController = TextEditingController(text: widget.outstandingBalance.toStringAsFixed(2));
    _discountController = TextEditingController(text: '0');
  }

  // --- Logic: Cash + Discount must always equal Outstanding Balance ---

  void _onCashChanged(String val) {
    if (val.isEmpty) return;
    double cash = double.tryParse(val) ?? 0;
    // If I pay X cash, the rest must be discount
    double discount = widget.outstandingBalance - cash;
    if (discount < 0) discount = 0; // Cannot have negative discount (overpayment)
    _discountController.text = discount.toStringAsFixed(2);
  }

  void _onDiscountChanged(String val) {
    if (val.isEmpty) return;
    double discount = double.tryParse(val) ?? 0;
    // If I give Y discount, the customer must pay the rest
    double cash = widget.outstandingBalance - discount;
    if (cash < 0) cash = 0;
    _cashController.text = cash.toStringAsFixed(2);
  }

  Future<void> _submitSettle() async {
    if (!_formKey.currentState!.validate()) return;

    double cash = double.tryParse(_cashController.text) ?? 0;
    double disc = double.tryParse(_discountController.text) ?? 0;
    double total = cash + disc;

    // Safety Check: Allow 0.5 rupee rounding difference
    if ((widget.outstandingBalance - total).abs() > 0.5) {
      setState(() => _errorMessage = "Total (Cash + Discount) must equal outstanding: ₹${widget.outstandingBalance.toStringAsFixed(2)}");
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await _apiService.settleLoan(
        loanId: widget.loanId,
        settlementAmount: _cashController.text,
        discountAmount: _discountController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settle & Close Loan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200)
                ),
                child: Column(
                  children: [
                    Text("Outstanding Balance", style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                    Text("₹${widget.outstandingBalance.toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cash Input
              TextFormField(
                controller: _cashController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cash Payment (₹)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)),
                onChanged: _onCashChanged,
              ),
              const SizedBox(height: 15),

              // Discount Input
              TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Discount / Waiver (₹)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_offer)),
                onChanged: _onDiscountChanged,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitSettle,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('SETTLE', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}