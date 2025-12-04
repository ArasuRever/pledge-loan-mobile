import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class SettleLoanDialog extends StatefulWidget {
  final int loanId;
  final double outstandingBalance;
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
    // Initialize: Cash = Full Balance, Discount = 0
    _cashController = TextEditingController(text: widget.outstandingBalance.toStringAsFixed(0));
    _discountController = TextEditingController(text: '0');
  }

  // --- OPTIMIZED LOGIC: Prevents "Lag" by only updating the OTHER field ---

  void _onCashChanged(String val) {
    if (val.isEmpty) return;
    double cash = double.tryParse(val) ?? 0;

    // Logic: Discount = Total - Cash
    double newDiscount = widget.outstandingBalance - cash;
    if (newDiscount < 0) newDiscount = 0;

    // Only update text if value changed significantly (prevents cursor glitches)
    String newDiscText = newDiscount.toStringAsFixed(0);
    if (_discountController.text != newDiscText) {
      _discountController.text = newDiscText;
    }

    // Refresh UI to update "Total/Status" without rebuilding the inputs unnecessarily
    setState(() {});
  }

  void _onDiscountChanged(String val) {
    if (val.isEmpty) return;
    double discount = double.tryParse(val) ?? 0;

    // Logic: Cash = Total - Discount
    double newCash = widget.outstandingBalance - discount;
    if (newCash < 0) newCash = 0;

    String newCashText = newCash.toStringAsFixed(0);
    if (_cashController.text != newCashText) {
      _cashController.text = newCashText;
    }

    setState(() {});
  }

  double get _currentTotal {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final disc = double.tryParse(_discountController.text) ?? 0;
    return cash + disc;
  }

  Future<void> _submitSettle() async {
    // Math Check
    if ((widget.outstandingBalance - _currentTotal).abs() > 1.0) {
      setState(() => _errorMessage = "Total must equal Outstanding Amount.");
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
    final total = _currentTotal;
    final isBalanced = (widget.outstandingBalance - total).abs() < 1.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Row(children: [
                Icon(Icons.verified, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text("Settlement Checkout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ]),
              const Divider(height: 30),

              // SUMMARY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Outstanding", style: TextStyle(fontSize: 16)),
                  Text("₹${widget.outstandingBalance.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              // INPUTS (Optimized)
              _buildInput("Cash Payment", _cashController, Colors.green, _onCashChanged),
              const SizedBox(height: 12),
              _buildInput("Discount / Waiver", _discountController, Colors.orange, _onDiscountChanged),

              const Divider(height: 30),

              // STATUS ROW (Replaces "Remaining: 0")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Status", style: TextStyle(fontWeight: FontWeight.bold)),
                  isBalanced
                      ? Row(children: const [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text("Balanced", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  ])
                      : Text(
                      "Pending: ₹${(widget.outstandingBalance - total).toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                  ),
                ],
              ),

              if (_errorMessage != null)
                Padding(padding: const EdgeInsets.only(top: 10), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || !isBalanced) ? null : _submitSettle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBalanced ? Colors.green[700] : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("CONFIRM SETTLEMENT"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, Color color, Function(String) onChanged) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      // Removed setState inside TextField rebuilds to improve performance
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        prefixIcon: Icon(Icons.money, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }
}