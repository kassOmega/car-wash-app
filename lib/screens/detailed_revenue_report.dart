import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/expense.dart';
import '../models/money_collection.dart';
import '../services/firebase_service.dart';

class DetailedRevenueReport extends StatelessWidget {
  final DateTimeRange dateRange;

  const DetailedRevenueReport({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detailed Revenue Report'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Summary Cards
            StreamBuilder<List<CarWash>>(
              stream: firebaseService.getCarWashesByDateRange(
                  dateRange.start,
                  DateTime(dateRange.end.year, dateRange.end.month,
                      dateRange.end.day, 23, 59, 59)),
              builder: (context, carWashSnapshot) {
                return StreamBuilder<List<Expense>>(
                  stream: firebaseService.getExpensesByDateRange(
                      dateRange.start, dateRange.end),
                  builder: (context, expenseSnapshot) {
                    return StreamBuilder<List<MoneyCollection>>(
                      stream: firebaseService.getMoneyCollectionsByDateRange(
                          dateRange.start, dateRange.end),
                      builder: (context, collectionSnapshot) {
                        final carWashes = carWashSnapshot.data ?? [];
                        final expenses = expenseSnapshot.data ?? [];
                        final collections = collectionSnapshot.data ?? [];

                        final totalRevenue = carWashes.fold(
                            0.0, (sum, wash) => sum + wash.amount);
                        final totalExpenses = expenses.fold(
                            0.0, (sum, expense) => sum + expense.amount);
                        final totalCollected = collections.fold(0.0,
                            (sum, collection) => sum + collection.totalAmount);
                        final netProfit = totalRevenue - totalExpenses;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: _buildStatCard('Total Revenue',
                                        totalRevenue, Colors.green)),
                                Expanded(
                                    child: _buildStatCard('Total Expenses',
                                        totalExpenses, Colors.red)),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                    child: _buildStatCard(
                                        'Net Profit',
                                        netProfit,
                                        netProfit >= 0
                                            ? Colors.blue
                                            : Colors.orange)),
                                Expanded(
                                    child: _buildStatCard('Money Collected',
                                        totalCollected, Colors.purple)),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            SizedBox(height: 16),

            // Detailed Sections
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Car Washes'),
                        Tab(text: 'Expenses'),
                        Tab(text: 'Collections'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCarWashesList(),
                          _buildExpensesList(),
                          _buildCollectionsList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              'ETB ${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarWashesList() {
    return Consumer<FirebaseService>(
      builder: (context, firebaseService, child) {
        return StreamBuilder<List<CarWash>>(
          stream: firebaseService.getCarWashesByDateRange(
              dateRange.start,
              DateTime(dateRange.end.year, dateRange.end.month,
                  dateRange.end.day, 23, 59, 59)),
          builder: (context, snapshot) {
            final carWashes = snapshot.data ?? [];
            return ListView.builder(
              itemCount: carWashes.length,
              itemBuilder: (context, index) {
                final wash = carWashes[index];
                return ListTile(
                  leading: Icon(Icons.local_car_wash, color: Colors.blue),
                  title: Text(
                      '${wash.vehicleType} - ETB ${wash.amount.toStringAsFixed(0)}'),
                  subtitle: Text(DateFormat('MMM dd, HH:mm').format(wash.date)),
                  trailing: Text(wash.plateNumber ?? 'No Plate'),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExpensesList() {
    return Consumer<FirebaseService>(
      builder: (context, firebaseService, child) {
        return StreamBuilder<List<Expense>>(
          stream: firebaseService.getExpensesByDateRange(
              dateRange.start, dateRange.end),
          builder: (context, snapshot) {
            final expenses = snapshot.data ?? [];
            return ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return ListTile(
                  leading: Icon(Icons.money_off, color: Colors.red),
                  title: Text(
                      '${expense.category} - ETB ${expense.amount.toStringAsFixed(2)}'),
                  subtitle: Text(expense.description),
                  trailing: Text(DateFormat('MMM dd').format(expense.date)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCollectionsList() {
    return Consumer<FirebaseService>(
      builder: (context, firebaseService, child) {
        return StreamBuilder<List<MoneyCollection>>(
          stream: firebaseService.getMoneyCollectionsByDateRange(
              dateRange.start, dateRange.end),
          builder: (context, snapshot) {
            final collections = snapshot.data ?? [];
            return ListView.builder(
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return ListTile(
                  leading:
                      Icon(Icons.account_balance_wallet, color: Colors.green),
                  title:
                      Text('ETB ${collection.totalAmount.toStringAsFixed(2)}'),
                  subtitle: Text('Collected by: ${collection.collectedByName}'),
                  trailing: Text(
                      DateFormat('MMM dd').format(collection.collectionDate)),
                );
              },
            );
          },
        );
      },
    );
  }
}
