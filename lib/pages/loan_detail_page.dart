import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/widgets/add_payment_dialog.dart';
import 'package:pledge_loan_mobile/widgets/settle_loan_dialog.dart';
import 'package:pledge_loan_mobile/widgets/add_principal_dialog.dart';
import 'package:pledge_loan_mobile/widgets/renew_loan_dialog.dart';
import 'package:pledge_loan_mobile/pages/edit_loan_page.dart';
import 'package:pledge_loan_mobile/pages/customer_detail_page.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pledge_loan_mobile/pages/loan_history_page.dart';

class LoanDetailPage extends StatefulWidget {
  final int loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  State<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends State<LoanDetailPage> {
  late Future<LoanDetail> _loanDetailFuture;
  String? _userRole;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadLoanDetails();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role');
      });
    }
  }

  void _loadLoanDetails() {
    setState(() {
      _loanDetailFuture = _apiService.getLoanDetails(widget.loanId);
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'overdue': return Colors.red;
      case 'active': return Colors.green;
      case 'renewed': return Colors.blue;
      case 'paid': return Colors.blueGrey;
      case 'forfeited': return Colors.black54;
      default: return Colors.black;
    }
  }

  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AddPaymentDialog(
          loanId: widget.loanId,
          onSuccess: () {
            _loadLoanDetails();
            _showMessage('Payment added successfully!');
          }),
    );
  }

  void _showSettleLoanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => SettleLoanDialog(
          loanId: widget.loanId,
          onSuccess: () {
            _loadLoanDetails();
            _showMessage('Loan settled successfully!');
          }),
    );
  }

  void _showAddPrincipalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AddPrincipalDialog(
          loanId: widget.loanId,
          onSuccess: () {
            _loadLoanDetails();
            _showMessage('Principal added successfully!');
          }),
    );
  }

  void _showRenewLoanDialog(LoanDetail loan) {
    showDialog(
      context: context,
      builder: (context) => RenewLoanDialog(
        loanId: loan.id,
        currentPrincipal: loan.principalAmount,
        totalInterestOwed: loan.calculated.totalInterestOwed,
        currentInterestRate: loan.interestRate,
        onSuccess: (newLoanId) {
          _showMessage('Loan Renewed Successfully!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoanDetailPage(loanId: newLoanId)),
          );
        },
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _navigateToHistory() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => LoanHistoryPage(loanId: widget.loanId)));
  }

  void _onMenuSelected(String value, LoanDetail loan) {
    if (value == 'edit_loan') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditLoanPage(loanDetail: loan))).then((wasUpdated) {
        if (wasUpdated == true) {
          _loadLoanDetails();
          _showMessage('Loan details updated!');
        }
      });
    }
  }

  Future<void> _handleDeleteLoan() async {
    final confirmed = await _showConfirmationDialog(context, 'Delete Loan?', 'Are you sure you want to move this loan to the recycle bin?');
    if (confirmed) {
      try {
        await _apiService.softDeleteLoan(widget.loanId);
        if (!mounted) return;
        _showMessage('Loan moved to recycle bin.');
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context, String title, String content) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('DELETE')),
        ],
      ),
    )) ?? false;
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd-MMM-yyyy').format(date);
    } catch (e) { return dateStr.split('T')[0]; }
  }

  String formatStat(String value) {
    try { return '₹${double.parse(value).toStringAsFixed(0)}'; } catch (e) { return '₹---'; }
  }

  // --- PDF GENERATOR ---
  Future<void> _generateAndSharePdf(LoanDetail loan) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('SRI KUBERA BANKERS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('123 Main Bazaar, Salem, Tamil Nadu - 636001', style: const pw.TextStyle(fontSize: 12))),
              pw.Center(child: pw.Text('Phone: 9876543210', style: const pw.TextStyle(fontSize: 12))),
              pw.Divider(),
              pw.Center(child: pw.Text('PLEDGE TICKET / LOAN RECEIPT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))),
              pw.SizedBox(height: 20),

              // Info Grid
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('LOAN DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                          pw.SizedBox(height: 5),
                          pw.Text('Loan No: ${loan.bookLoanNumber ?? loan.id}'),
                          pw.Text('Date: ${_formatDateString(loan.pledgeDate)}'),
                          pw.Text('Principal: ${formatStat(loan.principalAmount)}'),
                          pw.Text('Interest: ${loan.interestRate}% p.m.'),
                          pw.Text('Due Date: ${_formatDateString(loan.dueDate)}'),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CUSTOMER DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                          pw.SizedBox(height: 5),
                          pw.Text('Name: ${loan.customerName}'),
                          pw.Text('Phone: ${loan.phoneNumber}'),
                          pw.Text('Address: ${loan.address ?? 'N/A'}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Text('PARTICULARS OF PLEDGED ARTICLES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                headers: ['Description', 'Type', 'Gross Wt', 'Net Wt', 'Purity'],
                data: [
                  [
                    '${loan.description} (${loan.itemType})',
                    loan.itemType?.toUpperCase() ?? 'N/A',
                    '${loan.grossWeight ?? loan.weight ?? '-'} g',
                    '${loan.netWeight ?? '-'} g',
                    loan.purity ?? '-',
                  ]
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Appraised Value: ${formatStat(loan.appraisedValue ?? '0')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text('Signature of Borrower'),
                  ]),
                  pw.Column(children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text('For SRI KUBERA BANKERS'),
                    pw.Text('(Authorized Signatory)', style: const pw.TextStyle(fontSize: 10)),
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Loan_Invoice_${loan.bookLoanNumber}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Loan Details'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLoanDetails),

          FutureBuilder<LoanDetail>(
              future: _loanDetailFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final loan = snapshot.data!;
                final isActive = loan.status == 'active' || loan.status == 'overdue';
                // FIX: Removed isDeletable logic to allow Admin to delete any loan

                return Row(
                  children: [
                    if (isActive)
                      IconButton(
                        icon: const Icon(Icons.autorenew),
                        tooltip: 'Renew / Rollover Loan',
                        onPressed: () => _showRenewLoanDialog(loan),
                      ),

                    IconButton(icon: const Icon(Icons.history), tooltip: 'View History', onPressed: _navigateToHistory),

                    if (isActive)
                      IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit Loan Details', onPressed: () => _onMenuSelected('edit_loan', loan),
                      ),

                    IconButton(
                      icon: const Icon(Icons.print),
                      tooltip: 'Print Invoice PDF',
                      onPressed: () => _generateAndSharePdf(loan),
                    ),

                    // FIX: Always show delete for Admin
                    if (_userRole == 'admin')
                      IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete Loan', color: Colors.red, onPressed: _handleDeleteLoan),
                  ],
                );
              }),
        ],
      ),
      body: FutureBuilder<LoanDetail>(
        future: _loanDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)));
          if (!snapshot.hasData) return const Center(child: Text('Loan not found.'));

          final loan = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildLoanSummaryCard(loan),
                    const SizedBox(height: 16),
                    _buildInterestBreakdownCard(loan),
                    const SizedBox(height: 16),
                    _buildItemDetailsCard(loan),
                    const SizedBox(height: 16),
                    _buildTransactionsList(loan.transactions),
                    const SizedBox(height: 16),
                    // --- NEW: Settlement Summary ---
                    _buildSettlementSummary(loan),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              _buildActionButtons(loan),
            ],
          );
        },
      ),
    );
  }

  // --- NEW: Settlement Summary Widget ---
  Widget _buildSettlementSummary(LoanDetail loan) {
    if (loan.status != 'paid') return const SizedBox.shrink();

    final allTxs = loan.transactions;
    // Transaction groups
    final payTxs = allTxs.where((t) => ['interest', 'principal', 'settlement'].contains(t.paymentType));
    final discountTxs = allTxs.where((t) => t.paymentType == 'discount');

    // Use Total Principal from Loan Details (Correct value including initial)
    final totalPrincipal = double.tryParse(loan.principalAmount) ?? 0.0;

    final totalCashPaid = payTxs.fold(0.0, (sum, t) => sum + double.parse(t.amountPaid));
    final totalDiscount = discountTxs.fold(0.0, (sum, t) => sum + double.parse(t.amountPaid));

    // Derived Interest
    final totalInterestGenerated = (totalCashPaid + totalDiscount) - totalPrincipal;
    final totalPayable = totalPrincipal + totalInterestGenerated;

    return Card(
      elevation: 2,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('Settlement Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[800])),
              ],
            ),
            const Divider(),
            _buildSummaryRow('Total Principal Disbursed', totalPrincipal),
            _buildSummaryRow('+ Interest & Charges', totalInterestGenerated),
            const Divider(),
            _buildSummaryRow('Total Payable', totalPayable, isBold: true),
            _buildSummaryRow('- Total Cash Paid', totalCashPaid, color: Colors.green),
            if (totalDiscount > 0)
              _buildSummaryRow('- Discount / Waiver', totalDiscount, color: Colors.red),
            const Divider(),
            _buildSummaryRow('Outstanding Balance', 0.0, isBold: true, color: Colors.black),

            if (loan.closedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Center(child: Text('Settled on ${_formatDateString(loan.closedDate)}', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14, color: color)
          ),
        ],
      ),
    );
  }

  Widget _buildLoanSummaryCard(LoanDetail loan) {
    final stats = loan.calculated;
    final isClosed = loan.status != 'active' && loan.status != 'overdue';

    // FIX: Filter transactions for Total Paid to EXCLUDE discounts
    final paymentsReceived = loan.transactions.where((tx) => tx.paymentType != 'disbursement' && tx.paymentType != 'discount');
    final totalPaidReal = paymentsReceived.fold(0.0, (sum, tx) => sum + double.parse(tx.amountPaid));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailPage(customerId: loan.customerId, customerName: loan.customerName)));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loan.customerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo, decoration: TextDecoration.underline)),
                        const SizedBox(height: 4),
                        Text(loan.phoneNumber ?? 'No phone', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                _buildStatusBadge(loan.status),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('Book #', loan.bookLoanNumber ?? 'N/A'),
            _buildDetailRow('Pledge Date', _formatDateString(loan.pledgeDate)),

            if (isClosed && loan.closedDate != null)
              _buildDetailRow('Settled On', _formatDateString(loan.closedDate), valueColor: Colors.blueGrey)
            else
              _buildDetailRow('Due Date', _formatDateString(loan.dueDate)),

            const Divider(height: 24),

            _buildDetailRow('Total Principal', formatStat(loan.principalAmount), isBold: true),
            _buildDetailRow('Interest Rate', '${loan.interestRate}% / month'),

            if (isClosed) ...[
              const SizedBox(height: 10),
              const Divider(),
              // Use recalculated real total paid
              _buildDetailRow('Total Paid', '₹${totalPaidReal.toStringAsFixed(0)}', valueColor: Colors.green, isTotal: true),
            ] else ...[
              _buildDetailRow('Principal Paid', formatStat(stats.principalPaid), valueColor: Colors.green),
              _buildDetailRow('Interest Paid', formatStat(stats.interestPaid), valueColor: Colors.green),
              const Divider(height: 24),
              _buildDetailRow('Outstanding Principal', formatStat(stats.outstandingPrincipal), valueColor: Colors.red),
              _buildDetailRow('Outstanding Interest', formatStat(stats.outstandingInterest), valueColor: Colors.red),
              const SizedBox(height: 8),
              _buildDetailRow('TOTAL DUE', formatStat(stats.amountDue), valueColor: Colors.red, isTotal: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInterestBreakdownCard(LoanDetail loan) {
    if (loan.interestBreakdown.isEmpty || (loan.status != 'active' && loan.status != 'overdue')) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Interest Breakdown", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900], fontSize: 16)),
            const SizedBox(height: 12),
            ...loan.interestBreakdown.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)), Text("${_formatDateString(item.date)} • ${formatStat(item.amount)}", style: TextStyle(fontSize: 12, color: Colors.blue[800]))])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(formatStat(item.interest), style: const TextStyle(fontWeight: FontWeight.bold)), Text("${item.months.toStringAsFixed(2)} mo", style: TextStyle(fontSize: 12, color: Colors.blue[800]))]),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard(LoanDetail loan) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.inventory_2_outlined, color: Colors.grey), const SizedBox(width: 8), Text('Pledged Item', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]),
            const Divider(height: 24),
            if (loan.itemImageDataUrl != null)
              Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(loan.itemImageDataUrl!.split(',')[1]), height: 180, width: double.infinity, fit: BoxFit.cover)))),
            _buildDetailRow('Type', loan.itemType ?? 'N/A'),
            _buildDetailRow('Description', loan.description ?? 'N/A'),
            _buildDetailRow('Quality', loan.quality ?? 'N/A'),
            const Divider(),
            _buildDetailRow('Gross Wt', '${loan.grossWeight ?? loan.weight ?? '0'} g'),
            _buildDetailRow('Net Wt', '${loan.netWeight ?? '0'} g'),
            _buildDetailRow('Purity', loan.purity ?? 'N/A'),
            _buildDetailRow('Appraised Value', formatStat(loan.appraisedValue ?? '0')),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ...transactions.map((tx) {
          String subtitle = _formatDateString(tx.paymentDate);
          if (tx.changedByUsername != null) subtitle += ' • ${tx.changedByUsername}';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: tx.color.withAlpha(30), child: Icon(tx.icon, color: tx.color, size: 20)),
              title: Text('${tx.paymentType[0].toUpperCase()}${tx.paymentType.substring(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              trailing: Text('${tx.paymentType == 'disbursement' ? '+' : '-'}${tx.formattedAmount}', style: TextStyle(color: tx.color, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          );
        }).toList()
      ],
    );
  }

  Widget _buildActionButtons(LoanDetail loan) {
    if (loan.status != 'active' && loan.status != 'overdue') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _showAddPrincipalDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Add Principal', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _showAddPaymentDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Add Payment', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _showSettleLoanDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Settle & Close Loan', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isTotal = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isTotal || isBold ? FontWeight.bold : FontWeight.w500, fontSize: isTotal ? 18 : 14, color: valueColor ?? Colors.black87))),
        ],
      ),
    );
  }
}