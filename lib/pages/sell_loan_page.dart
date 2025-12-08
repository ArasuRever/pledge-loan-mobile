import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class SellLoanPage extends StatefulWidget {
  final int loanId;
  final String currentAmountDue;

  const SellLoanPage({super.key, required this.loanId, required this.currentAmountDue});

  @override
  State<SellLoanPage> createState() => _SellLoanPageState();
}

class _SellLoanPageState extends State<SellLoanPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  File? _capturedPhoto;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _salePriceController.dispose();
    _notesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _capturedPhoto = File(picked.path));
    }
  }

  Future<void> _submitForfeiture() async {
    if (!_formKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature is required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Export signature to file
      final Uint8List? data = await _signatureController.toPngBytes();
      if (data == null) throw Exception('Failed to generate signature');

      final tempDir = await getTemporaryDirectory();
      final signatureFile = await File('${tempDir.path}/signature.png').create();
      await signatureFile.writeAsBytes(data);

      await _apiService.forfeitLoan(
        loanId: widget.loanId,
        salePrice: _salePriceController.text,
        notes: _notesController.text,
        signatureFile: signatureFile,
        photoFile: _capturedPhoto,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell / Forfeit Item'), backgroundColor: Colors.red[800], foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Outstanding Balance", style: TextStyle(fontSize: 12, color: Colors.red)),
                    Text("₹${widget.currentAmountDue}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                  ])),
                ]),
              ),
              const SizedBox(height: 24),

              // Inputs
              TextFormField(
                controller: _salePriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Final Sale Price', border: OutlineInputBorder(), prefixText: '₹ '),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes / Reason', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Camera Section
              const Text("Proof of Sale (Photo)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickPhoto,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey)),
                  child: _capturedPhoto == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.camera_alt, size: 40, color: Colors.grey), Text("Tap to take photo")])
                      : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_capturedPhoto!, fit: BoxFit.cover)),
                ),
              ),
              const SizedBox(height: 24),

              // Signature Section
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Customer / Agent Signature", style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => _signatureController.clear(), child: const Text("Clear")),
              ]),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: Signature(
                  controller: _signatureController,
                  height: 150,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForfeiture,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRM FORFEITURE"),
              )),
            ],
          ),
        ),
      ),
    );
  }
}