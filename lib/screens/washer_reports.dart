import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/washer.dart';
import '../services/firebase_service.dart';

class WasherReports extends StatefulWidget {
  final Washer washer;

  const WasherReports({super.key, required this.washer});

  @override
  _WasherReportsState createState() => _WasherReportsState();
}

class _WasherReportsState extends State<WasherReports> {
  String _selectedPeriod = 'Daily';

  // --- Report Calculation Logic ---

  Map<String, dynamic> _calculateReport(List<CarWash> carWashes) {
    final now = DateTime.now();
    List<CarWash> filteredCarWashes;

    switch (_selectedPeriod) {
      case 'Daily':
        final today = DateTime(now.year, now.month, now.day);
        filteredCarWashes = carWashes.where((wash) {
          final washDate =
              DateTime(wash.date.year, wash.date.month, wash.date.day);
          return washDate == today;
        }).toList();
        break;
      case 'Weekly':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filteredCarWashes = carWashes.where((wash) {
          // Filter by date AND by the specific washer ID
          return wash.date.isAfter(startOfWeek);
        }).toList();
        break;
      case 'Monthly':
        final startOfMonth = DateTime(now.year, now.month, 1);
        filteredCarWashes = carWashes.where((wash) {
          return wash.date.isAfter(startOfMonth);
        }).toList();
        break;
      default:
        filteredCarWashes = carWashes;
    }

    final totalRevenue =
        filteredCarWashes.fold(0.0, (sum, wash) => sum + wash.amount);

    // Calculate total earnings based on the washer's commission percentage
    final totalEarnings = totalRevenue * (widget.washer.percentage / 100);

    return {
      'totalRevenue': totalRevenue,
      'totalEarnings': totalEarnings,
      'vehicleCount': filteredCarWashes.length,
    };
  }

  // --- UI Builder Methods ---

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

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.washer.name}\'s Report'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPeriodButton('Daily'),
                    _buildPeriodButton('Weekly'),
                    _buildPeriodButton('Monthly'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // StreamBuilder fetches all washes for this specific washer
            Expanded(
              child: StreamBuilder<List<CarWash>>(
                stream: firebaseService.getCarWashesByWasher(widget.washer.id),
                builder: (context, carWashSnapshot) {
                  if (carWashSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final carWashes = carWashSnapshot.data ?? [];
                  final report = _calculateReport(carWashes);

                  return Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_selectedPeriod Performance',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(),
                              Text(
                                  'Commission Rate: ${widget.washer.percentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatCard('Vehicles',
                                      '${report['vehicleCount']}', Colors.blue),
                                  _buildStatCard(
                                      'Revenue',
                                      '\$${report['totalRevenue'].toStringAsFixed(2)}',
                                      Colors.green),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Display Washer's calculated earnings prominently
                              _buildStatCard(
                                  'Total Earnings',
                                  '\$${report['totalEarnings'].toStringAsFixed(2)}',
                                  Colors.orange),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
