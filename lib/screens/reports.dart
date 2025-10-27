import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/expense.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'washer_reports.dart'; // Import the new file

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  _ReportsState createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  String _selectedPeriod = 'Daily';

  Map<String, dynamic> _calculateReport(List<CarWash> carWashes,
      List<Expense> expenses, List<Washer> washers, AuthProvider authProvider) {
    final now = DateTime.now();
    List<CarWash> filteredCarWashes;
    List<Expense> filteredExpenses;

    // Define the start date based on the selected period
    DateTime startDate;
    switch (_selectedPeriod) {
      case 'Daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Weekly':
        startDate = now.subtract(
            Duration(days: now.weekday - 1)); // Start of the week (Monday)
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Yearly':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    // Adjust end date to include all of today
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Filter Car Washes by period
    filteredCarWashes = carWashes.where((wash) {
      // If the user is a cashier or washer, only show their washes
      if (authProvider.isCashier || authProvider.isWasher) {
        return wash.date
                .isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            wash.date.isBefore(endDate.add(const Duration(seconds: 1))) &&
            wash.recordedBy == authProvider.user!.uid;
      }
      return wash.date
              .isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          wash.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();

    // Filter Expenses by period (only visible to Owner)
    filteredExpenses = expenses.where((expense) {
      return expense.date
              .isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          expense.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();

    // Calculate Totals
    final totalRevenue =
        filteredCarWashes.fold(0.0, (sum, wash) => sum + wash.amount);
    final totalExpenses =
        filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final netIncome = totalRevenue - totalExpenses;
    final totalWashes = filteredCarWashes.length;

    // Calculate Washer Reports (Owner only)
    final washerReports = <String, Map<String, dynamic>>{};
    if (authProvider.isOwner) {
      for (var washer in washers) {
        final washerWashes = filteredCarWashes
            .where((wash) => wash.washerId == washer.id)
            .toList();
        final washerRevenue =
            washerWashes.fold(0.0, (sum, wash) => sum + wash.amount);
        final washerEarnings = washerRevenue * (washer.percentage / 100);

        washerReports[washer.id] = {
          'washer': washer,
          'vehicleCount': washerWashes.length,
          'totalRevenue': washerRevenue,
          'totalEarnings': washerEarnings,
        };
      }
    }

    return {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netIncome': netIncome,
      'totalWashes': totalWashes,
      'washerReports': washerReports.values.toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Determine the streams to listen to based on user role
    final carWashStream = authProvider.isWasher
        ? firebaseService.getCarWashesByWasher(authProvider.user!.uid)
        : firebaseService.getCarWashes();
    final expenseStream = authProvider.isOwner
        ? firebaseService.getExpenses()
        : Stream.value(<Expense>[]);
    final washerStream = authProvider.isOwner
        ? firebaseService.getWashers()
        : Stream.value(<Washer>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Period Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPeriodButton('Daily'),
                _buildPeriodButton('Weekly'),
                _buildPeriodButton('Monthly'),
                _buildPeriodButton('Yearly'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<CarWash>>(
                stream: carWashStream,
                builder: (context, carWashSnapshot) {
                  if (carWashSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final carWashes = carWashSnapshot.data ?? [];

                  return StreamBuilder<List<Expense>>(
                    stream: expenseStream,
                    builder: (context, expenseSnapshot) {
                      final expenses = expenseSnapshot.data ?? [];

                      return StreamBuilder<List<Washer>>(
                        stream: washerStream,
                        builder: (context, washerSnapshot) {
                          final washers = washerSnapshot.data ?? [];

                          // Calculate the report based on all data
                          final report = _calculateReport(
                              carWashes, expenses, washers, authProvider);

                          final totalRevenue = report['totalRevenue'];
                          final totalExpenses = report['totalExpenses'];
                          final netIncome = report['netIncome'];
                          final totalWashes = report['totalWashes'];
                          final washerReports =
                              report['washerReports'] as List<dynamic>;

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Summary Stats
                                Card(
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatCard('Washes',
                                                '$totalWashes', Colors.blue),
                                            _buildStatCard(
                                                'Revenue',
                                                '\$${totalRevenue.toStringAsFixed(2)}',
                                                Colors.green),
                                          ],
                                        ),
                                        if (authProvider.isOwner) ...[
                                          const Divider(height: 30),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildStatCard(
                                                  'Expenses',
                                                  '-\$${totalExpenses.toStringAsFixed(2)}',
                                                  Colors.red),
                                              _buildStatCard(
                                                  'Net Income',
                                                  '\$${netIncome.toStringAsFixed(2)}',
                                                  Colors.orange),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Washer Reports (Only for Owner)
                                if (authProvider.isOwner) ...[
                                  const Text('Washer Performance',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ...washerReports.map((report) {
                                    final Washer washer = report['washer'];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      elevation: 1,
                                      child: InkWell(
                                        // This is the new part for navigation
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  WasherReports(washer: washer),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(washer.name,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16)),
                                                    Text(
                                                        '${washer.percentage.toStringAsFixed(1)}% Commission',
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildStatCard(
                                                      'Washes',
                                                      '${report['vehicleCount']}',
                                                      Colors.blue),
                                                  const SizedBox(width: 16),
                                                  _buildStatCard(
                                                      'Earnings',
                                                      '\$${report['totalEarnings'].toStringAsFixed(2)}',
                                                      Colors.orange),
                                                  const Icon(
                                                      Icons.arrow_forward_ios,
                                                      size: 16,
                                                      color: Colors.grey),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _selectedPeriod == period ? Colors.purple : Colors.grey,
        foregroundColor: Colors.white,
      ),
      child: Text(period),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
