// screens/detailed_expenses_report.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../services/firebase_service.dart';

class DetailedExpensesReport extends StatelessWidget {
  final DateTimeRange dateRange;

  const DetailedExpensesReport({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses Details'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Expense>>(
        stream: firebaseService.getExpensesByDateRange(
            dateRange.start, dateRange.end),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data ?? [];

          // Group by category
          final Map<String, List<Expense>> groupedByCategory = {};
          for (final expense in expenses) {
            if (!groupedByCategory.containsKey(expense.category)) {
              groupedByCategory[expense.category] = [];
            }
            groupedByCategory[expense.category]!.add(expense);
          }

          // Calculate totals
          final totalExpenses =
              expenses.fold(0.0, (sum, expense) => sum + expense.amount);

          return Column(
            children: [
              // Summary
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Expenses',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                            Text(
                              'ETB ${totalExpenses.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.money_off, size: 40, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ),

              // Category Breakdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Breakdown by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),

              // Category List
              Expanded(
                child: ListView(
                  children: [
                    ...groupedByCategory.entries.map((entry) {
                      final category = entry.key;
                      final categoryExpenses = entry.value;
                      final categoryTotal = categoryExpenses.fold(
                          0.0, (sum, expense) => sum + expense.amount);
                      final percentage = totalExpenses > 0
                          ? (categoryTotal / totalExpenses * 100)
                          : 0;

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ExpansionTile(
                          leading: Icon(Icons.category, color: Colors.red),
                          title: Text(category),
                          subtitle: Text(
                              'ETB ${categoryTotal.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)'),
                          trailing: Chip(
                            label: Text('${categoryExpenses.length}'),
                            backgroundColor: Colors.red[50],
                          ),
                          children: [
                            ...categoryExpenses.map((expense) {
                              return ListTile(
                                leading:
                                    Icon(Icons.receipt, color: Colors.grey),
                                title: Text(expense.description),
                                subtitle: Text(
                                    DateFormat('MMM dd, yyyy - HH:mm')
                                        .format(expense.date)),
                                trailing: Text(
                                  'ETB ${expense.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
