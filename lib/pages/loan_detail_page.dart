// lib/pages/loan_detail_page.dart
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
import 'package:pledge_loan_mobile/pages/sell_loan_page.dart'; // Ensure this is imported
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

class _LoanDetailPageState extends State<LoanDetailPage> with SingleTickerProviderStateMixin {
  late Future<LoanDetail> _loanDetailFuture;
  String? _userRole;
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserRole();
    _loadLoanDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('role'));
  }

  void _loadLoanDetails() {
    setState(() {
      _loanDetailFuture = _apiService.getLoanDetails(widget.loanId);
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- ACTIONS (NEW & EXISTING) ---

  Future<void> _handleDeleteTransaction(int txId) async {
    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: const Text("Delete Transaction?"),
            content: const Text("This cannot be undone. It will revert the financial impact."),
            actions: [
              TextButton(onPressed:()=>Navigator.pop(ctx,false), child: const Text("Cancel")),
              TextButton(onPressed:()=>Navigator.pop(ctx,true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
            ]
        )
    );
    if(confirm == true) {
      try {
        await _apiService.deleteTransaction(txId);
        _loadLoanDetails();
        _showMessage("Transaction deleted.");
      } catch(e) { _showMessage(e.toString()); }
    }
  }

  Future<void> _handleUndoForfeit() async {
    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: const Text("Undo Forfeiture?"),
            content: const Text("Revert loan to active status and remove sale record?"),
            actions: [
              TextButton(onPressed:()=>Navigator.pop(ctx,false), child: const Text("Cancel")),
              TextButton(onPressed:()=>Navigator.pop(ctx,true), child: const Text("Undo", style: TextStyle(color: Colors.red))),
            ]
        )
    );
    if(confirm == true) {
      try {
        await _apiService.undoForfeit(widget.loanId);
        _loadLoanDetails();
        _showMessage("Forfeiture undone.");
      } catch(e) { _showMessage(e.toString()); }
    }
  }

  Future<void> _handleDeleteLoan() async {
    final confirmed = await _showConfirmationDialog(context, 'Delete Loan?', 'Are you sure you want to move this loan to the recycle bin?');
    if (confirmed) {
      try {
        await _apiService.softDeleteLoan(widget.loanId);
        if (!mounted) return;
        Navigator.pop(context);
        _showMessage('Loan moved to recycle bin.');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPaymentDialog(
          loanId: widget.loanId,
          onSuccess: () { _loadLoanDetails(); _showMessage('Payment added successfully!'); }),
    );
  }

  void _showSettleLoanDialog(double currentBalance) {
    showDialog(
      context: context,
      builder: (context) => SettleLoanDialog(
          loanId: widget.loanId,
          outstandingBalance: currentBalance,
          onSuccess: () { _loadLoanDetails(); _showMessage('Loan settled successfully!'); }),
    );
  }

  void _showAddPrincipalDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPrincipalDialog(
          loanId: widget.loanId,
          onSuccess: () { _loadLoanDetails(); _showMessage('Principal added successfully!'); }),
    );
  }

  void _showRenewLoanDialog(LoanDetail loan) {
    showDialog(
      context: context,
      builder: (context) => RenewLoanDialog(
        loanId: loan.id,
        currentPrincipal: loan.calculated.outstandingPrincipal,
        totalInterestOwed: loan.calculated.totalInterestOwed,
        currentInterestRate: loan.interestRate,
        onSuccess: (newLoanId) {
          _showMessage('Loan Renewed Successfully!');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoanDetailPage(loanId: newLoanId)));
        },
      ),
    );
  }

  Future<bool> _showConfirmationDialog(BuildContext context, String title, String content) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title), content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('DELETE')),
        ],
      ),
    )) ?? false;
  }

  String _calculateElapsedDisplay(String startDateStr, String? endDateStr) {
    try {
      final start = DateTime.parse(startDateStr);
      final end = endDateStr != null ? DateTime.parse(endDateStr) : DateTime.now();

      final days = end.difference(start).inDays;
      final months = (days / 30).floor();
      final remainingDays = days % 30;

      if (months == 0) return "$days Days";
      return "$months Mon, $remainingDays Days";
    } catch (e) {
      return "N/A";
    }
  }

  String _formatCurrency(String amount) {
    final amt = double.tryParse(amount) ?? 0.0;
    return '₹${amt.toStringAsFixed(2)}';
  }

  Future<void> _generateAndSharePdf(LoanDetail loan) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Center(child: pw.Text('SRI KUBERA BANKERS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('123 Main Bazaar, Salem - 636001 | Ph: 9876543210', style: const pw.TextStyle(fontSize: 12))),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text('LOAN RECEIPT #${loan.bookLoanNumber ?? loan.id}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Customer Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(loan.customerName),
              pw.Text(loan.phoneNumber ?? ''),
              pw.Text(loan.address ?? ''),
            ])),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Loan Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Principal: Rs. ${loan.principalAmount}'),
              pw.Text('Rate: ${loan.interestRate}%'),
              pw.Text('Date: ${loan.pledgeDate.split('T')[0]}'),
            ])),
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Item Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('${loan.itemType} - ${loan.description}'),
          pw.Text('Weight: ${loan.grossWeight ?? loan.weight}g'),
        ]);
      },
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Loan_${loan.bookLoanNumber}.pdf');
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: FutureBuilder<LoanDetail>(
        future: _loanDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center));
          if (!snapshot.hasData) return const Center(child: Text('Loan not found.'));

          final loan = snapshot.data!;

          // Calculate Net Balance and Discount
          final totalDiscount = loan.transactions
              .where((tx) => tx.paymentType == 'discount')
              .fold(0.0, (sum, tx) => sum + (double.tryParse(tx.amountPaid) ?? 0.0));

          final isClosed = loan.status == 'paid' || loan.status == 'forfeited';

          double amountDue = double.tryParse(loan.calculated.amountDue) ?? 0.0;
          if (isClosed) amountDue = 0; // Visual Freeze

          return Column(
            children: [
              // 1. HEADER
              _buildDarkHeader(loan, amountDue),

              // 2. TABS
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.black,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [Tab(text: "DETAILS"), Tab(text: "TIMELINE")],
                ),
              ),

              // 3. CONTENT
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: DETAILS
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildDynamicItemCard(loan),
                        const SizedBox(height: 16),
                        _buildInfoGrid(loan),
                        const SizedBox(height: 16),
                        _buildCalculationWorksheet(loan, totalDiscount),
                        const SizedBox(height: 100),
                      ],
                    ),
                    // TAB 2: TIMELINE (Re-organized)
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildInterestBreakdown(loan),
                        const SizedBox(height: 24),
                        _buildUnifiedTransactionHistory(loan, loan.transactions), // Pass Full Loan
                        const SizedBox(height: 100),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: FutureBuilder<LoanDetail>(
        future: _loanDetailFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return _buildBottomBar(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildBottomBar(LoanDetail loan) {
    final isForfeited = loan.status == 'forfeited';
    final isPaid = loan.status == 'paid';

    if (isForfeited) {
      // SPECIAL ACTIONS FOR FORFEITED LOANS
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _handleUndoForfeit,
          icon: const Icon(Icons.undo),
          label: const Text("UNDO FORFEITURE"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
        ),
      );
    }

    // Hide actions for Paid/Settled loans
    if (isPaid) return const SizedBox.shrink();

    // Standard Actions for Active/Overdue
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showAddPaymentDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("PAYMENT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showSettleLoanDialog(double.tryParse(loan.calculated.amountDue) ?? 0.0),
              icon: const Icon(Icons.check, size: 18),
              label: const Text("SETTLE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showMoreMenu(context, loan),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context, LoanDetail loan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loan.status == 'active' || loan.status == 'overdue') ...[
            ListTile(leading: const Icon(Icons.add_card), title: const Text("Add Principal"), onTap: () { Navigator.pop(context); _showAddPrincipalDialog(); }),
            ListTile(leading: const Icon(Icons.autorenew), title: const Text("Renew Loan"), onTap: () { Navigator.pop(context); _showRenewLoanDialog(loan); }),
            ListTile(leading: const Icon(Icons.gavel, color: Colors.orange), title: const Text("Forfeit / Sell Item"), onTap: () {
              Navigator.pop(context);
              // PASS FULL LOAN OBJECT TO SELL PAGE
              Navigator.push(context, MaterialPageRoute(builder: (c) => SellLoanPage(loan: loan)))
                  .then((val) { if(val == true) _loadLoanDetails(); });
            }),
            ListTile(leading: const Icon(Icons.edit), title: const Text("Edit Details"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => EditLoanPage(loanDetail: loan))).then((val) => { if(val==true) _loadLoanDetails() }); }),
          ],

          if (_userRole == 'admin')
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Loan", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _handleDeleteLoan(); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildDarkHeader(LoanDetail loan, double amountDue) {
    final isClosed = loan.status == 'paid' || loan.status == 'forfeited';
    String statusText = isClosed ? (loan.status == 'paid' ? "Settled" : "Forfeited") : "₹${amountDue.toStringAsFixed(0)}";

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 24, left: 20, right: 20),
      color: const Color(0xFF1E293B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.white70)),
              Row(children: [
                IconButton(onPressed: () => _generateAndSharePdf(loan), icon: const Icon(Icons.print, color: Colors.white70)),
                IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LoanHistoryPage(loanId: loan.id))), icon: const Icon(Icons.history, color: Colors.white70)),
              ]),
            ],
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CustomerDetailPage(customerId: loan.customerId, customerName: loan.customerName))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(loan.customerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                  child: Text("Loan #${loan.bookLoanNumber ?? loan.id}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone, size: 12, color: Colors.white54),
              const SizedBox(width: 4),
              Text(loan.phoneNumber ?? '', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("NET OUTSTANDING", style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                      statusText,
                      style: TextStyle(color: isClosed ? Colors.greenAccent : Colors.white, fontSize: 36, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              const Spacer(),
              _buildStatusBadge(loan.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg; Color text;
    switch (status) {
      case 'overdue': bg = Colors.redAccent; text = Colors.white; break;
      case 'active': bg = Colors.green; text = Colors.white; break;
      case 'paid': bg = Colors.grey; text = Colors.white; break;
      case 'forfeited': bg = Colors.orange; text = Colors.white; break;
      default: bg = Colors.blue; text = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildDynamicItemCard(LoanDetail loan) {
    final List<Map<String, String?>> itemFields = [
      {'label': 'Item Type', 'value': loan.itemType},
      {'label': 'Description', 'value': loan.description},
      {'label': 'Quality', 'value': loan.quality},
      {'label': 'Gross Weight', 'value': (loan.grossWeight ?? loan.weight) != null ? "${loan.grossWeight ?? loan.weight} g" : null},
      {'label': 'Net Weight', 'value': loan.netWeight != null ? "${loan.netWeight} g" : null},
      {'label': 'Purity', 'value': loan.purity},
      {'label': 'Appraised Value', 'value': loan.appraisedValue != null ? "₹${loan.appraisedValue}" : null},
    ];

    final validFields = itemFields.where((f) => f['value'] != null && f['value']!.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              const Text("Pledged Asset", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          if (loan.itemImageDataUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(base64Decode(loan.itemImageDataUrl!.split(',')[1]), height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            ),

          ...validFields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _itemDetailRow(field['label']!, field['value']!),
          )),
        ],
      ),
    );
  }

  Widget _itemDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildInfoGrid(LoanDetail loan) {
    final accumulatedInterest = loan.calculated.totalInterestOwed;
    final elapsedString = _calculateElapsedDisplay(loan.pledgeDate, loan.closedDate);

    final pAmt = double.tryParse(loan.principalAmount) ?? 0.0;
    final iAmt = double.tryParse(accumulatedInterest) ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildGridCard("Principal", "₹${pAmt.toStringAsFixed(0)}", Icons.account_balance_wallet, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildGridCard("Acc. Interest", "₹${iAmt.toStringAsFixed(0)}", Icons.trending_up, Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGridCard("Interest Rate", "${loan.interestRate}% / mo", Icons.percent, Colors.purple)),
            const SizedBox(width: 12),
            Expanded(child: _buildGridCard("Elapsed Time", elapsedString, Icons.timer, Colors.teal)),
          ],
        ),
      ],
    );
  }

  Widget _buildGridCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCalculationWorksheet(LoanDetail loan, double totalDiscount) {
    if (loan.interestBreakdown.isEmpty) return const SizedBox.shrink();
    final stats = loan.calculated;
    final isClosed = loan.status == 'paid' || loan.status == 'forfeited';

    final interestDueDisplay = isClosed ? "0" : stats.outstandingInterest;
    final amountDueDisplay = isClosed ? "0" : stats.amountDue;

    double parseSafe(String val) => double.tryParse(val) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.calculate_outlined, color: Colors.indigo, size: 20),
            SizedBox(width: 8),
            Text("Detailed Calculations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const Divider(),
          const SizedBox(height: 8),

          _calcRow("Total Principal", "₹${parseSafe(loan.principalAmount).toStringAsFixed(0)}", isBold: true),
          _calcRow("- Principal Repaid", "₹${parseSafe(stats.principalPaid).toStringAsFixed(0)}", color: Colors.green),
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, indent: 200)),
          _calcRow("Net Principal", "₹${parseSafe(stats.outstandingPrincipal).toStringAsFixed(0)}", isBold: true, color: Colors.blue[800]),

          const SizedBox(height: 20),
          const Text("Interest Breakdown:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),

          ...loan.interestBreakdown.reversed.map((item) {
            final isPayment = item.status == 'payment';
            final isDiscount = item.label.toLowerCase().contains('discount');

            if (isPayment) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(item.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDiscount ? Colors.orange[800] : Colors.green[800])),
                  Text("₹${parseSafe(item.amount).abs().toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDiscount ? Colors.orange[800] : Colors.green[800])),
                ]),
              );
            }

            final principalPart = parseSafe(item.amount).toStringAsFixed(0);
            final monthsPart = item.months.toStringAsFixed(2);
            final ratePart = loan.interestRate;
            final isAdjustment = item.amount == "-";

            final formula = isAdjustment
                ? "Adjustment to Min 1 Month"
                : "₹$principalPart × $ratePart% × $monthsPart mo";

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("${item.label} ${item.date.contains('T') ? '(${item.date.split('T')[0]})' : ''}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text("₹${parseSafe(item.interest).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  Text(formula, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            );
          }),

          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, indent: 200)),
          _calcRow("Total Accumulated Interest", "₹${parseSafe(stats.totalInterestOwed).toStringAsFixed(0)}", isBold: true),
          _calcRow("- Interest Paid", "₹${parseSafe(stats.interestPaid).toStringAsFixed(0)}", color: Colors.green),

          if (totalDiscount > 0)
            _calcRow("- Discount / Waiver", "₹${totalDiscount.toStringAsFixed(0)}", color: Colors.red),

          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, indent: 200)),
          _calcRow("Net Interest Due", "₹${parseSafe(interestDueDisplay).toStringAsFixed(0)}", isBold: true, color: Colors.orange[800]),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isClosed ? Colors.green.withOpacity(0.1) : Colors.indigo[50], // Green BG if Closed
              borderRadius: BorderRadius.circular(8),
              border: isClosed ? Border.all(color: Colors.green.withOpacity(0.3)) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isClosed ? "TOTAL PAID" : "TOTAL PAYABLE",
                        style: TextStyle(fontWeight: FontWeight.bold, color: isClosed ? Colors.green[800] : Colors.indigo)
                    ),
                    if (isClosed)
                      Text(
                          "(${loan.status.toUpperCase()})",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[800], letterSpacing: 0.5)
                      ),
                  ],
                ),
                Text(
                    isClosed
                        ? "₹${parseSafe(stats.totalPaid).toStringAsFixed(0)}" // Show Total Paid if closed
                        : "₹${parseSafe(amountDueDisplay).toStringAsFixed(0)}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isClosed ? Colors.green[800] : Colors.indigo)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, color: color ?? Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildInterestBreakdown(LoanDetail loan) {
    if (loan.interestBreakdown.isEmpty) return const SizedBox.shrink();

    // Sort oldest first (API sends newest first, so we reverse it for timeline view)
    final breakdownList = List.from(loan.interestBreakdown.reversed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Loan Ledger / Timeline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          ...breakdownList.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == breakdownList.length - 1;

            final isPayment = item.status == 'payment';
            final isDiscount = item.label.toLowerCase().contains('discount');

            Color dotColor;
            if (isPayment) {
              dotColor = isDiscount ? Colors.orange : Colors.green;
            } else {
              dotColor = Colors.blue;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                    if (!isLast) Container(width: 2, height: 40, color: Colors.grey.withOpacity(0.3)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: isPayment
                        ? _buildPaymentRow(item, isDiscount)
                        : _buildAccrualRow(item),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(InterestBreakdownItem item, bool isDiscount) {
    final amount = double.tryParse(item.amount)?.abs().toStringAsFixed(0) ?? "0";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isDiscount ? "Discount Applied" : "Payment Received", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDiscount ? Colors.orange[800] : Colors.green[800])),
        Text(item.date.split('T')[0], style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text("Amount: ₹$amount", style: TextStyle(fontWeight: FontWeight.w600, color: isDiscount ? Colors.orange[900] : Colors.green[900])),
      ],
    );
  }

  Widget _buildAccrualRow(InterestBreakdownItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text("${item.date.split('T')[0]}  •  ${item.months} Months", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text("Interest: ₹${double.tryParse(item.interest)?.toStringAsFixed(0) ?? '0'}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildUnifiedTransactionHistory(LoanDetail loan, List<Transaction> transactions) {
    if (transactions.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No transactions yet.")));

    // Ensure sorted by date descending (Newest first)
    transactions.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Detailed Transactions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (c, i) => const Divider(height: 1, indent: 56),
            itemBuilder: (ctx, index) {
              final tx = transactions[index];

              // --- SPECIAL SALE CARD (Matches Web App Logic) ---
              if (tx.paymentType == 'sale') {
                final p = double.tryParse(loan.calculated.outstandingPrincipal) ?? 0;
                final i = double.tryParse(loan.calculated.totalInterestOwed) ?? 0;
                final costBasis = p + i;
                final salePrice = double.tryParse(tx.amountPaid) ?? 0;
                final totalVal = salePrice + costBasis; // New logic: Sale + Principal + Interest

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("ITEM SOLD", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _handleDeleteTransaction(tx.id))
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Sold For:"), Text("₹${salePrice.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                      ]),
                      Divider(color: Colors.red.withOpacity(0.2)),
                      const Text("Calculation:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      _miniRow("Principal", p),
                      _miniRow("Interest", i),
                      _miniRow("Cost (Bought For)", costBasis, isBold: true),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Total (Sale+P+I):", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${totalVal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))
                      ]),
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerRight, child: Text(tx.formattedDate, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                    ],
                  ),
                );
              }

              IconData icon; Color color; String displayType = tx.paymentType.toUpperCase();

              if (tx.paymentType == 'disbursement') {
                icon = Icons.arrow_outward; color = Colors.blue; displayType = "PRINCIPAL DISBURSED";
              } else if (tx.paymentType == 'discount') {
                icon = Icons.local_offer; color = Colors.orange; displayType = "DISCOUNT APPLIED";
              } else {
                icon = Icons.arrow_downward; color = Colors.green; displayType = "PAYMENT (${tx.paymentType.toUpperCase()})";
              }

              return ListTile(
                leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
                title: Text(displayType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("${tx.formattedDate} • ${tx.changedByUsername ?? 'sys'}", style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tx.formattedAmount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => _handleDeleteTransaction(tx.id))
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniRow(String label, double val, {bool isBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold?FontWeight.bold:FontWeight.normal)),
      Text("₹${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, fontWeight: isBold?FontWeight.bold:FontWeight.normal))
    ]);
  }
}