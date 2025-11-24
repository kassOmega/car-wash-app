// screens/detailed_car_washes_report.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/washer.dart';
import '../services/firebase_service.dart';

class DetailedCarWashesReport extends StatelessWidget {
  final DateTimeRange dateRange;

  const DetailedCarWashesReport({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Car Washes Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CarWash>>(
        stream: firebaseService.getCarWashesByDateRange(
          dateRange.start,
          DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day,
              23, 59, 59),
        ),
        builder: (context, carWashSnapshot) {
          return StreamBuilder<List<Washer>>(
            stream: firebaseService.getWashers(),
            builder: (context, washerSnapshot) {
              if (carWashSnapshot.connectionState == ConnectionState.waiting ||
                  washerSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final carWashes = carWashSnapshot.data ?? [];
              final washers = washerSnapshot.data ?? [];

              // Group by date
              final Map<String, List<CarWash>> groupedByDate = {};
              for (final wash in carWashes) {
                final dateKey = DateFormat('yyyy-MM-dd').format(wash.date);
                if (!groupedByDate.containsKey(dateKey)) {
                  groupedByDate[dateKey] = [];
                }
                groupedByDate[dateKey]!.add(wash);
              }

              // Calculate totals
              final totalRevenue =
                  carWashes.fold(0.0, (sum, wash) => sum + wash.amount);
              final totalVehicles = carWashes.length;

              return Column(
                children: [
                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Vehicles',
                            '$totalVehicles',
                            Icons.local_car_wash,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Revenue',
                            'ETB ${totalRevenue.toStringAsFixed(0)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detailed List
                  Expanded(
                    child: ListView(
                      children: [
                        ...groupedByDate.entries.map((entry) {
                          final date = DateTime.parse(entry.key);
                          final dailyWashes = entry.value;
                          final dailyRevenue = dailyWashes.fold(
                              0.0, (sum, wash) => sum + wash.amount);

                          return Card(
                            margin: EdgeInsets.all(8),
                            child: ExpansionTile(
                              leading: Icon(Icons.calendar_today,
                                  color: Colors.blue),
                              title:
                                  Text(DateFormat('MMM dd, yyyy').format(date)),
                              subtitle: Text(
                                  '${dailyWashes.length} vehicles - ETB ${dailyRevenue.toStringAsFixed(0)}'),
                              children: [
                                ...dailyWashes.map((wash) {
                                  final washer = washers.firstWhere(
                                    (w) => w.id == wash.washerId,
                                    orElse: () => Washer(
                                      id: '',
                                      name: 'Unknown',
                                      phone: '',
                                      percentage: 0,
                                      isActive: false,
                                      createdAt: DateTime.now(),
                                    ),
                                  );

                                  final participantNames =
                                      wash.participantWasherIds.map((id) {
                                    final participant = washers.firstWhere(
                                      (w) => w.id == id,
                                      orElse: () => Washer(
                                        id: id,
                                        name: 'Unknown',
                                        phone: '',
                                        percentage: 0,
                                        isActive: false,
                                        createdAt: DateTime.now(),
                                      ),
                                    );
                                    return participant.name;
                                  }).toList();

                                  return ListTile(
                                    leading: Icon(
                                        _getVehicleIcon(wash.vehicleType),
                                        color: Colors.blue),
                                    title: Text(
                                        '${wash.vehicleType} - ETB ${wash.amount.toStringAsFixed(0)}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Responsible: ${washer.name}'),
                                        if (participantNames.isNotEmpty)
                                          Text(
                                              'Helpers: ${participantNames.join(", ")}'),
                                        if (wash.plateNumber != null)
                                          Text('Plate: ${wash.plateNumber}'),
                                        Text(
                                            'Time: ${DateFormat('HH:mm').format(wash.date)}'),
                                      ],
                                    ),
                                    trailing: Chip(
                                      label: Text(wash.vehicleType),
                                      backgroundColor: Colors.blue[50],
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
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'suv':
        return Icons.airport_shuttle;
      case 'truck':
        return Icons.local_shipping;
      case 'motorcycle':
        return Icons.motorcycle;
      default:
        return Icons.directions_car;
    }
  }
}
