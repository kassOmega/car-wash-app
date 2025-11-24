// screens/detailed_equipment_report.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/equipment_usage.dart';
import '../services/firebase_service.dart';

class DetailedEquipmentReport extends StatelessWidget {
  final DateTimeRange dateRange;

  const DetailedEquipmentReport({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Equipment Usage Details'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<EquipmentUsage>>(
        stream: firebaseService.getEquipmentUsageByDateRange(
            dateRange.start, dateRange.end),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final equipmentUsage = snapshot.data ?? [];

          // Separate paid and unpaid
          final paidUsage =
              equipmentUsage.where((usage) => usage.isPaid).toList();
          final unpaidUsage =
              equipmentUsage.where((usage) => !usage.isPaid).toList();

          final totalRevenue =
              equipmentUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);
          final paidRevenue =
              paidUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);
          final unpaidRevenue =
              unpaidUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total',
                          'ETB ${totalRevenue.toStringAsFixed(0)}',
                          Icons.inventory_2,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Paid',
                          'ETB ${paidRevenue.toStringAsFixed(0)}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Unpaid',
                          'ETB ${unpaidRevenue.toStringAsFixed(0)}',
                          Icons.pending,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  tabs: [
                    Tab(text: 'All (${equipmentUsage.length})'),
                    Tab(text: 'Paid (${paidUsage.length})'),
                    Tab(text: 'Unpaid (${unpaidUsage.length})'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildUsageList(equipmentUsage, 'All Equipment Usage'),
                      _buildUsageList(paidUsage, 'Paid Equipment Usage'),
                      _buildUsageList(unpaidUsage, 'Unpaid Equipment Usage'),
                    ],
                  ),
                ),
              ],
            ),
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
            Icon(icon, size: 20, color: color),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageList(List<EquipmentUsage> usageList, String title) {
    if (usageList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No $title'),
          ],
        ),
      );
    }

    // Group by washer
    final Map<String, List<EquipmentUsage>> groupedByWasher = {};
    for (final usage in usageList) {
      if (!groupedByWasher.containsKey(usage.washerName)) {
        groupedByWasher[usage.washerName] = [];
      }
      groupedByWasher[usage.washerName]!.add(usage);
    }

    return ListView(
      children: [
        ...groupedByWasher.entries.map((entry) {
          final washerName = entry.key;
          final washerUsage = entry.value;
          final washerTotal =
              washerUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);

          return Card(
            margin: EdgeInsets.all(8),
            child: ExpansionTile(
              leading: Icon(Icons.person, color: Colors.orange),
              title: Text(washerName),
              subtitle: Text(
                  '${washerUsage.length} items - ETB ${washerTotal.toStringAsFixed(0)}'),
              children: [
                ...washerUsage.map((usage) {
                  return ListTile(
                    leading: Icon(Icons.build, color: Colors.blue),
                    title: Text(usage.storeItemName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Qty: ${usage.quantity} × ETB ${usage.unitPrice.toStringAsFixed(0)}'),
                        Text(DateFormat('MMM dd, yyyy').format(usage.date)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ETB ${usage.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Chip(
                          label: Text(usage.isPaid ? 'Paid' : 'Unpaid'),
                          backgroundColor:
                              usage.isPaid ? Colors.green : Colors.orange,
                          labelStyle:
                              TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
