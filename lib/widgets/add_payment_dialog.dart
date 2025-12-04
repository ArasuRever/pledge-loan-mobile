// lib/widgets/add_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class AddPaymentDialog extends StatefulWidget {
  final int loanId;
  final VoidCallback onSuccess;

  const AddPaymentDialog({super.key, required this.loanId, required this.onSuccess});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();

  String _paymentType = 'interest';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await _apiService.addPayment(
        loanId: widget.loanId,
        amount: _amountController.text,
        paymentType: _paymentType,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // TYPE SELECTION ROW
              Row(
                children: [
                  Expanded(child: _buildTypeCard('interest', 'Interest', Icons.timelapse)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTypeCard('principal', 'Principal', Icons.account_balance_wallet)),
                ],
              ),
              const SizedBox(height: 24),

              // AMOUNT INPUT
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (val) => (val == null || val.isEmpty || double.tryParse(val) == null) ? 'Enter valid amount' : null,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("CONFIRM PAYMENT", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(String value, String label, IconData icon) {
    final isSelected = _paymentType == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.blue[800] : Colors.grey)),
          ],
        ),
      ),
    );
  }
}