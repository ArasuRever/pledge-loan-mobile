// lib/pages/loan_detail_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/widgets/add_payment_dialog.dart';
import 'package:pledge_loan_mobile/widgets/settle_loan_dialog.dart';
import 'package:pledge_loan_mobile/widgets/add_principal_dialog.dart';
// --- 1. IMPORT THE NEW EDIT PAGE ---
import 'package:pledge_loan_mobile/pages/edit_loan_page.dart';

class LoanDetailPage extends StatefulWidget {
  final int loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  State<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends State<LoanDetailPage> {
  late Future<LoanDetail> _loanDetailFuture;

  @override
  void initState() {
    super.initState();
    _loadLoanDetails();
  }

  void _loadLoanDetails() {
    setState(() {
      _loanDetailFuture = ApiService().getLoanDetails(widget.loanId);
    });
  }

  Color _getStatusColor(String status) {
    // ... (unchanged)
    switch (status) {
      case 'overdue': return Colors.red;
      case 'active': return Colors.green;
      case 'paid': return Colors.blueGrey;
      case 'forfeited': return Colors.black54;
      default: return Colors.black;
    }
  }

  void _showAddPaymentDialog() {
    // ... (unchanged)
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
    // ... (unchanged)
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
    // ... (unchanged)
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

  // --- 2. UPDATE MENU HANDLER TO NAVIGATE ---
  void _onMenuSelected(String value, LoanDetail loan) {
    if (value == 'add_principal') {
      if (loan.status == 'active' || loan.status == 'overdue') {
        _showAddPrincipalDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot add principal to a ${loan.status} loan.')),
        );
      }
    } else if (value == 'edit_loan') {
      // Navigate to the new page and wait for a result
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditLoanPage(loanDetail: loan),
        ),
      ).then((wasUpdated) {
        // If the edit page pops 'true', refresh the details
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
                return PopupMenuButton<String>(
                  // --- 3. PASS THE 'loan' OBJECT TO THE HANDLER ---
                  onSelected: (value) => _onMenuSelected(value, loan),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'add_principal',
                      child: Text('Add Principal (Disburse)'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'edit_loan',
                      child: Text('Edit Loan Details'),
                    ),
                  ],
                );
              }
          ),
        ],
      ),
      body: FutureBuilder<LoanDetail>(
        future: _loanDetailFuture,
        builder: (context, snapshot) {
          // ... (rest of build method is unchanged)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
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
                    _buildItemDetailsCard(loan),
                    const SizedBox(height: 20),
                    _buildTransactionsList(loan.transactions),
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

  // ... in lib/pages/loan_detail_page.dart

  // --- REPLACE THIS FUNCTION ---
  Widget _buildLoanSummaryCard(LoanDetail loan) {
    // Get the calculated stats
    final stats = loan.calculated;

    // Helper to format the stats
    String formatStat(String value) {
      try {
        return '₹${double.parse(value).toStringAsFixed(0)}';
      } catch (e) {
        return '₹---';
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Customer Info ---
            Text(
              loan.customerName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(loan.phoneNumber ?? 'No phone', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),

            // --- Loan Info ---
            _buildDetailRow('Status', loan.status.toUpperCase(),
                valueColor: _getStatusColor(loan.status)
            ),
            _buildDetailRow('Book #', loan.bookLoanNumber ?? 'N/A'),
            _buildDetailRow('Pledge Date', loan.pledgeDate.split('T')[0]),
            _buildDetailRow('Due Date', loan.dueDate.split('T')[0]),

            const Divider(height: 24),

            // --- 1. DETAILED BREAKDOWN ---
            // This now uses the calculated outstanding principal
            _buildDetailRow('Total Principal', formatStat(stats.outstandingPrincipal)),
            _buildDetailRow('Interest Rate', '${loan.interestRate}% / month'),
            _buildDetailRow('Principal Paid', formatStat(stats.principalPaid), valueColor: Colors.green),
            _buildDetailRow('Interest Paid', formatStat(stats.interestPaid), valueColor: Colors.green),
            _buildDetailRow('Total Paid', formatStat(stats.totalPaid), valueColor: Colors.green),

            const Divider(height: 24),

            // --- 2. AMOUNT DUE CALCULATION ---
            _buildDetailRow('Outstanding Principal', formatStat(stats.outstandingPrincipal), valueColor: Colors.red),
            _buildDetailRow('Outstanding Interest', formatStat(stats.outstandingInterest), valueColor: Colors.red),
            const SizedBox(height: 8),
            _buildDetailRow(
              'TOTAL AMOUNT DUE (as of today)',
              formatStat(stats.amountDue),
              valueColor: Colors.red,
              isTotal: true, // Make it bigger
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard(LoanDetail loan) {
    // ... (unchanged)
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pledged Item', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
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
    // ... (unchanged)
    if (loan.status != 'active' && loan.status != 'overdue') {
      return const SizedBox.shrink();
    }

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
              onPressed: _showAddPaymentDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Payment', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 16),
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
            Text('Payment History', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tx.color.withAlpha(50),
                    child: Icon(tx.icon, color: tx.color),
                  ),
                  title: Text(
                    '${tx.paymentType[0].toUpperCase()}${tx.paymentType.substring(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(tx.formattedDate),
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

  // ... in lib/pages/loan_detail_page.dart

  // --- REPLACE THIS FUNCTION ---
  // ... in lib/pages/loan_detail_page.dart

  // --- REPLACE THIS FUNCTION ---
  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top
        children: [
          Expanded( // Wrap label in Expanded
            flex: 2, // Give label 2/3 of the space
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
          Expanded( // Wrap value in Expanded
            flex: 1, // Give value 1/3 of the space
            child: Text(
              value,
              textAlign: TextAlign.right, // Align value to the right
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