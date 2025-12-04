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

  // --- ACTIONS ---
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
        totalInterestOwed: loan.calculated.outstandingInterest,
        currentInterestRate: loan.interestRate,
        onSuccess: (newLoanId) {
          _showMessage('Loan Renewed Successfully!');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoanDetailPage(loanId: newLoanId)));
        },
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: FutureBuilder<LoanDetail>(
        future: _loanDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: Text('Loan not found.'));

          final loan = snapshot.data!;

          // Calculate Net Balance and Discount
          final totalDiscount = loan.transactions
              .where((tx) => tx.paymentType == 'discount')
              .fold(0.0, (sum, tx) => sum + (double.tryParse(tx.amountPaid) ?? 0.0));

          double amountDue = double.tryParse(loan.calculated.amountDue) ?? 0.0;
          if (loan.status == 'paid') amountDue = 0;

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
                        // A. Pledged Asset (First)
                        _buildDynamicItemCard(loan),
                        const SizedBox(height: 16),

                        // B. Info Grid
                        _buildInfoGrid(loan),
                        const SizedBox(height: 16),

                        // C. Calculation Worksheet
                        _buildCalculationWorksheet(loan, totalDiscount),
                        const SizedBox(height: 100),
                      ],
                    ),
                    // TAB 2: TIMELINE
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildInterestBreakdown(loan),
                        const SizedBox(height: 16),
                        _buildSplitTransactionHistory(loan.transactions), // <-- NEW SPLIT VIEW
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
          final loan = snapshot.data!;
          final balance = double.tryParse(loan.calculated.amountDue) ?? 0.0;

          if (loan.status != 'active' && loan.status != 'overdue') return const SizedBox.shrink();

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
                    onPressed: () => _showSettleLoanDialog(balance),
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
        },
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
          ListTile(leading: const Icon(Icons.add_card), title: const Text("Add Principal"), onTap: () { Navigator.pop(context); _showAddPrincipalDialog(); }),
          ListTile(leading: const Icon(Icons.autorenew), title: const Text("Renew Loan"), onTap: () { Navigator.pop(context); _showRenewLoanDialog(loan); }),
          ListTile(leading: const Icon(Icons.edit), title: const Text("Edit Details"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => EditLoanPage(loanDetail: loan))).then((val) => { if(val==true) _loadLoanDetails() }); }),
          if (_userRole == 'admin')
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Loan", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _handleDeleteLoan(); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildDarkHeader(LoanDetail loan, double amountDue) {
    final isClosed = loan.status == 'paid';

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
                      isClosed ? "Settled" : "₹${amountDue.toStringAsFixed(0)}",
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildGridCard("Principal", "₹${double.parse(loan.principalAmount).toStringAsFixed(0)}", Icons.account_balance_wallet, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildGridCard("Acc. Interest", "₹${double.parse(accumulatedInterest).toStringAsFixed(0)}", Icons.trending_up, Colors.orange)),
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
    final isPaid = loan.status == 'paid';

    final interestDueDisplay = isPaid ? "0" : stats.outstandingInterest;
    final amountDueDisplay = isPaid ? "0" : stats.amountDue;

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

          _calcRow("Total Principal", "₹${double.parse(loan.principalAmount).toStringAsFixed(0)}", isBold: true),
          _calcRow("- Principal Repaid", "₹${double.parse(stats.principalPaid).toStringAsFixed(0)}", color: Colors.green),
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, indent: 200)),
          _calcRow("Net Principal", "₹${double.parse(stats.outstandingPrincipal).toStringAsFixed(0)}", isBold: true, color: Colors.blue[800]),

          const SizedBox(height: 20),
          const Text("Interest Breakdown:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),

          ...loan.interestBreakdown.map((item) {
            final principalPart = double.parse(item.amount).toStringAsFixed(0);
            final monthsPart = item.months.toStringAsFixed(2);
            final ratePart = loan.interestRate;
            final formula = "₹$principalPart × $ratePart% × $monthsPart mo";
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("${item.label} (${item.date.split('T')[0]})", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text("₹${double.parse(item.interest).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  Text(formula, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            );
          }),

          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, indent: 200)),
          _calcRow("Total Accumulated Interest", "₹${double.parse(stats.totalInterestOwed).toStringAsFixed(0)}", isBold: true),
          _calcRow("- Interest Paid", "₹${double.parse(stats.interestPaid).toStringAsFixed(0)}", color: Colors.green),

          if (totalDiscount > 0)
            _calcRow("- Discount / Waiver", "₹${totalDiscount.toStringAsFixed(0)}", color: Colors.red),

          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, indent: 200)),
          _calcRow("Net Interest Due", "₹${double.parse(interestDueDisplay).toStringAsFixed(0)}", isBold: true, color: Colors.orange[800]),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL PAYABLE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                Text(
                    isPaid ? "Settled" : "₹${double.parse(amountDueDisplay).toStringAsFixed(0)}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isPaid ? Colors.green : Colors.indigo)
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Interest Segments", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...loan.interestBreakdown.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text("Factor: ${item.months} mo", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
                Text("₹${double.parse(item.interest).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // --- UPDATED: SPLIT TRANSACTION HISTORY ---
  Widget _buildSplitTransactionHistory(List<Transaction> transactions) {
    if (transactions.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No transactions yet.")));

    // Filter lists
    final payments = transactions.where((tx) => tx.paymentType != 'disbursement').toList();
    final disbursements = transactions.where((tx) => tx.paymentType == 'disbursement').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text("Transaction History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: PAYMENTS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Payments Received", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
                    if (payments.isEmpty) const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ...payments.map((tx) => _buildMiniTransactionCard(tx, isPayment: true))
                  ],
                ),
              ),
              const VerticalDivider(width: 24, thickness: 1),
              // RIGHT: DISBURSEMENTS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Principal Disbursed", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                    if (disbursements.isEmpty) const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ...disbursements.map((tx) => _buildMiniTransactionCard(tx, isPayment: false))
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTransactionCard(Transaction tx, {required bool isPayment}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: isPayment ? Colors.green.withOpacity(0.05) : Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx.formattedAmount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isPayment ? Colors.green[700] : Colors.blue[700])),
          const SizedBox(height: 2),
          Text(tx.paymentType.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(DateFormat('dd MMM yy').format(DateTime.parse(tx.paymentDate)), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          if (tx.changedByUsername != null)
            Text("by ${tx.changedByUsername}", style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}