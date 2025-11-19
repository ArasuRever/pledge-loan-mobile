// lib/pages/loan_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/widgets/add_payment_dialog.dart';
import 'package:pledge_loan_mobile/widgets/settle_loan_dialog.dart';
import 'package:pledge_loan_mobile/widgets/add_principal_dialog.dart';
import 'package:pledge_loan_mobile/pages/edit_loan_page.dart';
import 'dart:convert';
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
      case 'paid': return Colors.blueGrey;
      case 'forfeited': return Colors.black54;
      default: return Colors.black;
    }
  }

  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddPaymentDialog(
          loanId: widget.loanId,
          onSuccess: () {
            _loadLoanDetails();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      },
    );
  }

  void _showSettleLoanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SettleLoanDialog(
          loanId: widget.loanId,
          onSuccess: () {
            _loadLoanDetails();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Loan settled successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      },
    );
  }

  void _showAddPrincipalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddPrincipalDialog(
          loanId: widget.loanId,
          onSuccess: () {
            _loadLoanDetails();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Principal added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoanHistoryPage(loanId: widget.loanId),
      ),
    );
  }

  void _onMenuSelected(String value, LoanDetail loan) {
    if (value == 'edit_loan') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditLoanPage(loanDetail: loan),
        ),
      ).then((wasUpdated) {
        if (wasUpdated == true) {
          _loadLoanDetails();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loan details updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  Future<void> _handleDeleteLoan() async {
    final confirmed = await _showConfirmationDialog(
        context,
        'Delete Loan?',
        'Are you sure you want to move this loan to the recycle bin?');
    if (confirmed) {
      try {
        final result = await _apiService.softDeleteLoan(widget.loanId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Loan moved to recycle bin.'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<bool> _showConfirmationDialog(
      BuildContext context, String title, String content) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    )) ??
        false;
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd-MMM-yyyy').format(date);
    } catch (e) {
      return dateStr.split('T')[0];
    }
  }

  // Helper to format stats
  String formatStat(String value) {
    try {
      return '₹${double.parse(value).toStringAsFixed(0)}';
    } catch (e) {
      return '₹---';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoanDetails,
          ),
          FutureBuilder<LoanDetail>(
              future: _loanDetailFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final loan = snapshot.data!;
                final isActive =
                    loan.status == 'active' || loan.status == 'overdue';
                final isClosed =
                    loan.status == 'paid' || loan.status == 'forfeited';

                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history),
                      tooltip: 'View History',
                      onPressed: _navigateToHistory,
                    ),
                    if (isActive)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Loan Details',
                        onPressed: () => _onMenuSelected('edit_loan', loan),
                      ),
                    if (_userRole == 'admin' && isClosed)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete Loan',
                        color: Colors.red,
                        onPressed: _handleDeleteLoan,
                      ),
                  ],
                );
              }),
        ],
      ),
      body: FutureBuilder<LoanDetail>(
        future: _loanDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Loan not found.'));
          }

          final loan = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildLoanSummaryCard(loan),
                    const SizedBox(height: 20),
                    _buildInterestBreakdownCard(loan), // --- NEW WIDGET ---
                    const SizedBox(height: 20),
                    _buildItemDetailsCard(loan),
                    const SizedBox(height: 20),
                    _buildTransactionsList(loan.transactions),
                    const SizedBox(height: 80),
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

  Widget _buildLoanSummaryCard(LoanDetail loan) {
    final stats = loan.calculated;
    final isClosed = loan.status == 'paid' || loan.status == 'forfeited';

    double discountAmount = 0;
    try {
      final discountTx = loan.transactions.firstWhere(
            (tx) => tx.paymentType == 'discount',
        orElse: () => Transaction(id: 0, amountPaid: '0', paymentType: '', paymentDate: ''),
      );
      discountAmount = double.parse(discountTx.amountPaid);
    } catch (e) {
      // ignore
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loan.customerName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(loan.phoneNumber ?? 'No phone',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            _buildDetailRow('Status', loan.status.toUpperCase(),
                valueColor: _getStatusColor(loan.status)),
            _buildDetailRow('Book #', loan.bookLoanNumber ?? 'N/A'),
            _buildDetailRow('Pledge Date', _formatDateString(loan.pledgeDate)),

            if (isClosed && loan.closedDate != null)
              _buildDetailRow('Settled On', _formatDateString(loan.closedDate), valueColor: Colors.blueGrey)
            else
              _buildDetailRow('Due Date', _formatDateString(loan.dueDate)),

            const Divider(height: 24),

            _buildDetailRow('Total Principal', formatStat(loan.principalAmount)),
            _buildDetailRow('Interest Rate', '${loan.interestRate}% / month'),

            if (isClosed) ...[
              const SizedBox(height: 10),
              const Text("Settlement Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const Divider(),
              _buildDetailRow('Total Paid', formatStat(stats.totalPaid), valueColor: Colors.green, isTotal: true),
              if (discountAmount > 0)
                _buildDetailRow('Discount Given', '₹${discountAmount.toStringAsFixed(0)}', valueColor: Colors.orange),
            ] else ...[
              _buildDetailRow('Principal Paid', formatStat(stats.principalPaid), valueColor: Colors.green),
              _buildDetailRow('Interest Paid', formatStat(stats.interestPaid), valueColor: Colors.green),
              const Divider(height: 24),
              _buildDetailRow(
                  'Outstanding Principal', formatStat(stats.outstandingPrincipal),
                  valueColor: Colors.red),
              _buildDetailRow(
                  'Outstanding Interest', formatStat(stats.outstandingInterest),
                  valueColor: Colors.red),
              const SizedBox(height: 8),
              _buildDetailRow(
                'TOTAL AMOUNT DUE (today)',
                formatStat(stats.amountDue),
                valueColor: Colors.red,
                isTotal: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- NEW: INTEREST BREAKDOWN CARD ---
  Widget _buildInterestBreakdownCard(LoanDetail loan) {
    if (loan.interestBreakdown.isEmpty) return const SizedBox.shrink();

    // Only show if loan is active/overdue
    if (loan.status != 'active' && loan.status != 'overdue') return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color: Colors.blue[50], // Light blue background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Detailed Interest Breakdown", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900], fontSize: 16)),
            const SizedBox(height: 8),
            Text("Calculated by system based on ${loan.interestRate}% p.m.", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const Divider(),
            ...loan.interestBreakdown.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("${_formatDateString(item.date)} (${formatStat(item.amount)})", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatStat(item.interest), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("${item.months.toStringAsFixed(2)} months", style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL ACCRUED", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(formatStat(loan.calculated.totalInterestOwed), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard(LoanDetail loan) {
    // ... (unchanged logic)
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pledged Item', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            if (loan.itemImageDataUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                  child: Image.memory(
                    base64Decode(loan.itemImageDataUrl!.split(',')[1]),
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            _buildDetailRow('Type', loan.itemType ?? 'N/A'),
            _buildDetailRow('Description', loan.description ?? 'N/A'),
            _buildDetailRow('Weight', '${loan.weight ?? '0'} g'),
            _buildDetailRow('Quality', loan.quality ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(LoanDetail loan) {
    if (loan.status != 'active' && loan.status != 'overdue') {
      return const SizedBox.shrink();
    }
    // ... (unchanged)
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _showAddPrincipalDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
              const Text('Add Principal', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _showAddPaymentDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
              const Text('Add Payment', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _showSettleLoanDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Settle Loan', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    // ... (unchanged)
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No transactions recorded.'),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment History',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];

                String subtitle = _formatDateString(tx.paymentDate);
                if (tx.changedByUsername != null) {
                  subtitle += ' (by ${tx.changedByUsername})';
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tx.color.withAlpha(50),
                    child: Icon(tx.icon, color: tx.color),
                  ),
                  title: Text(
                    '${tx.paymentType[0].toUpperCase()}${tx.paymentType.substring(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Text(
                    '${tx.paymentType == 'disbursement' ? '+' : '-'}${tx.formattedAmount}',
                    style: TextStyle(
                      color: tx.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTotal ? 18 : 15,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}