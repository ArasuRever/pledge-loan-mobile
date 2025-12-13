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

  // Money In
  final _interestPaidController = TextEditingController();
  final _principalPaidController = TextEditingController();

  // Money Out
  final _principalAddedController = TextEditingController();

  late TextEditingController _newRateController;

  bool _deductFirstMonth = false;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Calculations
  double get _oldPrincipal => double.tryParse(widget.currentPrincipal) ?? 0;
  double get _totalInterest => double.tryParse(widget.totalInterestOwed) ?? 0;

  double get _intPaid => double.tryParse(_interestPaidController.text) ?? 0;
  double get _prinPaid => double.tryParse(_principalPaidController.text) ?? 0;
  double get _prinAdded => double.tryParse(_principalAddedController.text) ?? 0;

  double get _unpaidInterest => (_totalInterest - _intPaid).clamp(0, double.infinity);

  // FORMULA: (Old - Paid) + TopUp + UnpaidInt
  double get _newPrincipal => ((_oldPrincipal - _prinPaid) + _prinAdded) + _unpaidInterest;

  @override
  void initState() {
    super.initState();
    _newRateController = TextEditingController(text: widget.currentInterestRate);

    // Listeners to update UI preview
    _interestPaidController.addListener(() => setState(() {}));
    _principalPaidController.addListener(() => setState(() {}));
    _principalAddedController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newBookNumberController.dispose();
    _interestPaidController.dispose();
    _principalPaidController.dispose();
    _principalAddedController.dispose();
    _newRateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPrincipal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Principal must be > 0")));
      return;
    }

    // Confirmation Logic
    String confirmMsg = "Renewal Summary:\n"
        "• New Principal: ₹${_newPrincipal.toStringAsFixed(0)}\n"
        "• New Rate: ${_newRateController.text}%\n";

    if (_deductFirstMonth) {
      confirmMsg += "• 1st Month Interest will be DEDUCTED now.\n";
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
        principalPaid: _principalPaidController.text.isEmpty ? '0' : _principalPaidController.text, // NEW
        principalAdded: _principalAddedController.text.isEmpty ? '0' : _principalAddedController.text, // NEW
        newPrincipal: _newPrincipal.toString(),
        newBookLoanNumber: _newBookNumberController.text,
        newInterestRate: _newRateController.text,
        deductFirstMonthInterest: _deductFirstMonth, // NEW
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess(result['newLoanId']);
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
      scrollable: true,
      title: const Text('Renew Loan', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _newBookNumberController,
                decoration: const InputDecoration(labelText: 'New Book Loan #', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // MONEY IN SECTION
              const Align(alignment: Alignment.centerLeft, child: Text("Money In (Payments)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interestPaidController,
                      decoration: const InputDecoration(labelText: 'Int. Paid', border: OutlineInputBorder(), prefixText: '₹'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _principalPaidController,
                      decoration: const InputDecoration(labelText: 'Prin. Paid', border: OutlineInputBorder(), prefixText: '₹'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // MONEY OUT SECTION
              const Align(alignment: Alignment.centerLeft, child: Text("Money Out (Top-up)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
              const SizedBox(height: 4),
              TextFormField(
                controller: _principalAddedController,
                decoration: const InputDecoration(labelText: 'Principal Top-up (Added)', border: OutlineInputBorder(), prefixText: '₹'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // NEW TERMS
              TextFormField(
                controller: _newRateController,
                decoration: const InputDecoration(labelText: 'New Interest Rate (%)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),

              CheckboxListTile(
                title: const Text("Deduct 1st Month Interest?", style: TextStyle(fontSize: 13)),
                value: _deductFirstMonth,
                onChanged: (val) => setState(() => _deductFirstMonth = val!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 10),
              // PREVIEW BOX
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _row("Old Principal", "₹${_oldPrincipal.toStringAsFixed(0)}"),
                    _row("- Principal Paid", "₹${_prinPaid.toStringAsFixed(0)}", color: Colors.green),
                    _row("+ Principal Top-up", "₹${_prinAdded.toStringAsFixed(0)}", color: Colors.blue),
                    _row("+ Unpaid Interest", "₹${_unpaidInterest.toStringAsFixed(0)}", color: Colors.orange[800]),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("New Principal:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${_newPrincipal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                      ],
                    ),
                  ],
                ),
              )
            ],
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

  Widget _row(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(fontSize: 12)), Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))],
      ),
    );
  }
}