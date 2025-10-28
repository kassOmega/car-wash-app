import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/expense.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class Reports extends StatefulWidget {
  @override
  _ReportsState createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  String _selectedPeriod = 'Daily';

  Map<String, dynamic> _calculateReport(
    List<CarWash> carWashes,
    List<Expense> expenses,
    List<Washer> washers,
    AuthProvider authProvider,
  ) {
    final now = DateTime.now();
    List<CarWash> filteredCarWashes;
    List<Expense> filteredExpenses;

    switch (_selectedPeriod) {
      case 'Daily':
        final today = DateTime(now.year, now.month, now.day);
        filteredCarWashes = carWashes.where((wash) {
          final washDate =
              DateTime(wash.date.year, wash.date.month, wash.date.day);
          return washDate == today;
        }).toList();
        filteredExpenses = expenses.where((expense) {
          final expenseDate =
              DateTime(expense.date.year, expense.date.month, expense.date.day);
          return expenseDate == today;
        }).toList();
        break;
      case 'Weekly':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filteredCarWashes = carWashes.where((wash) {
          return wash.date.isAfter(startOfWeek);
        }).toList();
        filteredExpenses = expenses.where((expense) {
          return expense.date.isAfter(startOfWeek);
        }).toList();
        break;
      case 'Monthly':
        final startOfMonth = DateTime(now.year, now.month, 1);
        filteredCarWashes = carWashes.where((wash) {
          return wash.date.isAfter(startOfMonth);
        }).toList();
        filteredExpenses = expenses.where((expense) {
          return expense.date.isAfter(startOfMonth);
        }).toList();
        break;
      default:
        filteredCarWashes = carWashes;
        filteredExpenses = expenses;
    }

    // If user is washer, only show their car washes
    if (authProvider.isWasher) {
      filteredCarWashes = filteredCarWashes
          .where((wash) => wash.washerId == authProvider.user?.uid)
          .toList();
    }

    final totalRevenue =
        filteredCarWashes.fold(0.0, (sum, wash) => sum + wash.amount);
    final totalExpenses =
        filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final netProfit = totalRevenue - totalExpenses;

    final washerEarnings = <String, double>{};
    for (final wash in filteredCarWashes) {
      final washer = washers.firstWhere(
        (w) => w.id == wash.washerId,
        orElse: () => Washer(
          id: '',
          name: 'Unknown Washer',
          phone: '',
          percentage: 0,
          isActive: false,
          createdAt: DateTime.now(),
        ),
      );
      final earnings = wash.amount * (washer.percentage / 100);
      washerEarnings.update(
        washer.name,
        (value) => value + earnings,
        ifAbsent: () => earnings,
      );
    }

    return {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'vehicleCount': filteredCarWashes.length,
      'washerEarnings': washerEarnings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Period Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Select Period',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPeriodButton('Daily'),
                        _buildPeriodButton('Weekly'),
                        _buildPeriodButton('Monthly'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Reports Content
            Expanded(
              child: StreamBuilder<List<CarWash>>(
                stream: authProvider.isWasher
                    ? firebaseService
                        .getCarWashesByWasher(authProvider.user!.uid)
                    : firebaseService.getCarWashes(),
                builder: (context, carWashSnapshot) {
                  return StreamBuilder<List<Expense>>(
                    stream: (authProvider.isOwner || authProvider.isCashier)
                        ? firebaseService.getExpenses()
                        : Stream.value([]), // Washers can't see expenses
                    builder: (context, expenseSnapshot) {
                      return StreamBuilder<List<Washer>>(
                        stream: firebaseService.getWashers(),
                        builder: (context, washerSnapshot) {
                          // Handle loading state
                          if (carWashSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              expenseSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              washerSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                      color: Colors.purple),
                                  SizedBox(height: 16),
                                  Text('Loading reports...'),
                                ],
                              ),
                            );
                          }

                          // Handle errors
                          if (carWashSnapshot.hasError ||
                              expenseSnapshot.hasError ||
                              washerSnapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 64, color: Colors.red),
                                  SizedBox(height: 16),
                                  Text(
                                    'Error loading data',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.red),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => setState(() {}),
                                    child: Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final carWashes = carWashSnapshot.data ?? [];
                          final expenses = expenseSnapshot.data ?? [];
                          final washers = washerSnapshot.data ?? [];

                          final report = _calculateReport(
                              carWashes, expenses, washers, authProvider);

                          return _buildReportContent(
                              report, authProvider, washers);
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

  Widget _buildReportContent(Map<String, dynamic> report,
      AuthProvider authProvider, List<Washer> washers) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary Statistics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    '$_selectedPeriod Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 16),

                  // First row of stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Vehicles Washed',
                        '${report['vehicleCount']}',
                        Icons.local_car_wash,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Total Revenue',
                        '\$${report['totalRevenue'].toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Second row of stats (for owners/cashiers only)
                  if (authProvider.isOwner || authProvider.isCashier)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Total Expenses',
                          '\$${report['totalExpenses'].toStringAsFixed(2)}',
                          Icons.money_off,
                          Colors.red,
                        ),
                        _buildStatCard(
                          'Net Profit',
                          '\$${report['netProfit'].toStringAsFixed(2)}',
                          Icons.trending_up,
                          report['netProfit'] >= 0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Washer Earnings Section
          if ((authProvider.isOwner || authProvider.isCashier) &&
              (report['washerEarnings'] as Map<String, double>).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'Washer Earnings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._buildWasherEarningsList(
                        report['washerEarnings'] as Map<String, double>,
                        authProvider,
                        washers),
                  ],
                ),
              ),
            ),

          // Washer's Personal Earnings
          if (authProvider.isWasher &&
              (report['washerEarnings'] as Map<String, double>).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'My Earnings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._buildWasherEarningsList(
                        report['washerEarnings'] as Map<String, double>,
                        authProvider,
                        washers),
                  ],
                ),
              ),
            ),

          // Empty State
          if ((report['washerEarnings'] as Map<String, double>).isEmpty &&
              report['vehicleCount'] == 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Data Available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No ${_selectedPeriod.toLowerCase()} reports found for the selected period',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildWasherEarningsList(Map<String, double> washerEarnings,
      AuthProvider authProvider, List<Washer> washers) {
    final entries = washerEarnings.entries.toList();

    // Sort by earnings (descending)
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) {
      // If washer, only show their earnings
      if (authProvider.isWasher) {
        final washer = washers.firstWhere(
          (w) => w.name == entry.key,
          orElse: () => Washer(
            id: '',
            name: '',
            phone: '',
            percentage: 0,
            isActive: false,
            createdAt: DateTime.now(),
          ),
        );
        if (washer.id != authProvider.user?.uid) {
          return SizedBox.shrink();
        }
      }

      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.purple[100],
            radius: 20,
            child: Text(
              entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            entry.key,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            '\$${entry.value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = period;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.purple : Colors.grey[300],
            foregroundColor: isSelected ? Colors.white : Colors.grey[700],
            elevation: isSelected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            period,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
