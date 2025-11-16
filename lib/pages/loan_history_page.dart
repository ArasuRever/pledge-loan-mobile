// lib/pages/loan_history_page.dart
// NO IMPORT for package_exports.dart (this was the error)
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
        title: Text('Loan History (ID: ${widget.loanId})'),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' changed '),
                            TextSpan(
                                text: item.fieldChanged,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' from '),
                            TextSpan(
                                text: "'${item.oldValue ?? 'nothing'}'",
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontStyle: FontStyle.italic)),
                            const TextSpan(text: ' to '),
                            TextSpan(
                                text: "'${item.newValue ?? 'nothing'}'",
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}