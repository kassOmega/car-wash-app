import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/equipment_usage.dart';
import '../services/firebase_service.dart';

class DetailedEquipmentUsageScreen extends StatefulWidget {
  final DateTimeRange dateRange;
  final bool showPaidOnly;
  final bool showUnpaidOnly;

  const DetailedEquipmentUsageScreen({
    super.key,
    required this.dateRange,
    this.showPaidOnly = false,
    this.showUnpaidOnly = false,
  });

  @override
  _DetailedEquipmentUsageScreenState createState() =>
      _DetailedEquipmentUsageScreenState();
}

class _DetailedEquipmentUsageScreenState
    extends State<DetailedEquipmentUsageScreen> {
  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showPaidOnly
              ? 'Paid Equipment Usage'
              : widget.showUnpaidOnly
                  ? 'Unpaid Equipment Usage'
                  : 'All Equipment Usage',
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<EquipmentUsage>>(
        stream: firebaseService.getEquipmentUsageByDateRange(
          widget.dateRange.start,
          widget.dateRange.end,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading equipment usage',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                ],
              ),
            );
          }

          final equipmentUsage = snapshot.data ?? [];

          // Filter based on payment status
          List<EquipmentUsage> filteredUsage;
          if (widget.showPaidOnly) {
            filteredUsage =
                equipmentUsage.where((usage) => usage.isPaid).toList();
          } else if (widget.showUnpaidOnly) {
            filteredUsage =
                equipmentUsage.where((usage) => !usage.isPaid).toList();
          } else {
            filteredUsage = equipmentUsage;
          }

          if (filteredUsage.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No equipment usage found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Date Range: ${DateFormat('MMM dd, yyyy').format(widget.dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(widget.dateRange.end)}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calculate totals
          final totalAmount =
              filteredUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);
          final totalItems = filteredUsage.length;
          final paidCount = filteredUsage.where((u) => u.isPaid).length;
          final unpaidCount = filteredUsage.where((u) => !u.isPaid).length;

          return Column(
            children: [
              // Summary Card
              Card(
                margin: EdgeInsets.all(16),
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Equipment Usage Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Total Items', '$totalItems'),
                          _buildMiniStat('Total Amount',
                              'ETB ${totalAmount.toStringAsFixed(2)}'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Paid', '$paidCount', Colors.green),
                          _buildMiniStat(
                              'Unpaid', '$unpaidCount', Colors.orange),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(widget.dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(widget.dateRange.end)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // List of equipment usage
              Expanded(
                child: ListView.builder(
                  itemCount: filteredUsage.length,
                  itemBuilder: (context, index) {
                    final usage = filteredUsage[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: usage.isPaid
                              ? Colors.green[100]
                              : Colors.orange[100],
                          child: Icon(
                            usage.isPaid ? Icons.check : Icons.pending,
                            color: usage.isPaid ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          usage.storeItemName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Washer: ${usage.washerName}'),
                            Text('Quantity: ${usage.quantity}'),
                            Text(
                                'Unit Price: ETB ${usage.unitPrice.toStringAsFixed(2)}'),
                            Text(
                                'Date: ${DateFormat('MMM dd, HH:mm').format(usage.date)}'),
                            if (usage.isPaid && usage.paidDate != null)
                              Text(
                                  'Paid: ${DateFormat('MMM dd, HH:mm').format(usage.paidDate!)}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ETB ${usage.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    usage.isPaid ? Colors.green : Colors.orange,
                              ),
                            ),
                            Chip(
                              label: Text(
                                usage.isPaid ? 'Paid' : 'Unpaid',
                                style: TextStyle(fontSize: 10),
                              ),
                              backgroundColor: usage.isPaid
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                              padding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, [Color? color]) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color ?? Colors.orange,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
