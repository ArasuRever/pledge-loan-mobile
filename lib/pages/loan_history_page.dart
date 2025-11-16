// lib/pages/loan_history_page.dart
import 'package:flutter/material.dart';
import 'package:pledge_loan_mobile/models/loan_history_model.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';

class LoanHistoryPage extends StatefulWidget {
  final int loanId;
  const LoanHistoryPage({super.key, required this.loanId});

  @override
  State<LoanHistoryPage> createState() => _LoanHistoryPageState();
}

class _LoanHistoryPageState extends State<LoanHistoryPage> {
  late Future<List<LoanHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiService().getLoanHistory(widget.loanId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Combined History (ID: ${widget.loanId})'),
      ),
      body: FutureBuilder<List<LoanHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No history found for this loan.'));
          }

          final historyList = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final item = historyList[index];
              // Render a different card based on the event type
              return item.eventType == 'edit'
                  ? _buildEditHistoryCard(item)
                  : _buildTransactionHistoryCard(item);
            },
          );
        },
      ),
    );
  }

  // --- WIDGET FOR 'edit' EVENTS ---
  Widget _buildEditHistoryCard(LoanHistoryItem item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.formattedTimestamp,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.blueGrey),
            ),
            const Divider(height: 12.0),
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                      text: item.changedByUsername,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' changed '),
                  TextSpan(
                      text: item.fieldChanged,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' from '),
                  TextSpan(
                      text: "'${item.oldValue ?? 'nothing'}'",
                      style: const TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic)),
                  const TextSpan(text: ' to '),
                  TextSpan(
                      text: "'${item.newValue ?? 'nothing'}'",
                      style: const TextStyle(
                          color: Colors.black,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET FOR 'transaction' EVENTS ---
  Widget _buildTransactionHistoryCard(LoanHistoryItem item) {
    final isDisbursement = item.paymentType == 'disbursement';
    final color = isDisbursement ? Colors.red : Colors.green;
    final sign = isDisbursement ? '+' : '-';
    final title = isDisbursement ? 'Disbursement' : 'Payment (${item.paymentType})';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      color: color.withOpacity(0.05), // Light background tint
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.formattedTimestamp,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.blueGrey),
            ),
            const Divider(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                            text: title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: ' processed by '),
                        TextSpan(
                            text: item.changedByUsername,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
                Text(
                  '$sign${item.formattedAmount}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}