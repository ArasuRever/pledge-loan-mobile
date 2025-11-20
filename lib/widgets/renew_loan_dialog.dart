// lib/widgets/renew_loan_dialog.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class RenewLoanDialog extends StatefulWidget {
  final int loanId;
  final String currentPrincipal;
  final String totalInterestOwed;
  final String currentInterestRate;
  final Function(int newLoanId) onSuccess;

  const RenewLoanDialog({
    super.key,
    required this.loanId,
    required this.currentPrincipal,
    required this.totalInterestOwed,
    required this.currentInterestRate,
    required this.onSuccess,
  });

  @override
  State<RenewLoanDialog> createState() => _RenewLoanDialogState();
}

class _RenewLoanDialogState extends State<RenewLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newBookNumberController = TextEditingController();
  final _interestPaidController = TextEditingController();
  late TextEditingController _newRateController;

  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Calculations for Preview
  double get _oldPrincipal => double.tryParse(widget.currentPrincipal) ?? 0;
  double get _totalInterest => double.tryParse(widget.totalInterestOwed) ?? 0;
  double get _interestPaid => double.tryParse(_interestPaidController.text) ?? 0;

  double get _unpaidInterest => (_totalInterest - _interestPaid).clamp(0, double.infinity);
  double get _newPrincipal => _oldPrincipal + _unpaidInterest;

  @override
  void initState() {
    super.initState();
    _newRateController = TextEditingController(text: widget.currentInterestRate);
    _interestPaidController.addListener(() => setState(() {})); // Refresh UI on typing
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Confirmation Logic
    String confirmMsg = "This will CLOSE the current loan and CREATE a new one.";
    if (_unpaidInterest > 1) {
      confirmMsg += "\n\n⚠️ WARNING: You are not paying full interest.\n₹${_unpaidInterest.toStringAsFixed(2)} will be added to the Principal.";
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Renewal"),
        content: Text(confirmMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("PROCEED")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.renewLoan(
        oldLoanId: widget.loanId,
        interestPaid: _interestPaidController.text.isEmpty ? '0' : _interestPaidController.text,
        newBookLoanNumber: _newBookNumberController.text,
        newInterestRate: _newRateController.text,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        widget.onSuccess(result['newLoanId']); // Callback
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renew Loan', style: TextStyle(color: Colors.green)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _newBookNumberController,
                  decoration: const InputDecoration(labelText: 'New Book Loan #', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _interestPaidController,
                        decoration: const InputDecoration(labelText: 'Interest Paid (₹)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _newRateController,
                        decoration: const InputDecoration(labelText: 'New Rate (%)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // PREVIEW BOX
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _unpaidInterest > 0 ? Colors.orange[50] : Colors.green[50],
                    border: Border.all(color: _unpaidInterest > 0 ? Colors.orange : Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("New Principal:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("₹${_newPrincipal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      if (_unpaidInterest > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "(+ ₹${_unpaidInterest.toStringAsFixed(2)} unpaid interest added)",
                            style: TextStyle(color: Colors.red[700], fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('RENEW'),
        ),
      ],
    );
  }
}