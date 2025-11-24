// screens/issued_items_list_screen.dart - FIXED WITH ACCORDION
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/equipment_usage.dart';
import '../models/washer.dart';
import '../services/firebase_service.dart';

class IssuedItemsListScreen extends StatefulWidget {
  const IssuedItemsListScreen({super.key});

  @override
  _IssuedItemsListScreenState createState() => _IssuedItemsListScreenState();
}

class _IssuedItemsListScreenState extends State<IssuedItemsListScreen> {
  DateTimeRange? _selectedDateRange;
  String? _selectedWasherId;
  String? _selectedItemName;
  List<Washer> _washers = [];
  List<String> _itemNames = [];
  final Map<String, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: 30));
    _selectedDateRange = DateTimeRange(start: startDate, end: endDate);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 30)),
        end: DateTime.now(),
      );
      _selectedWasherId = null;
      _selectedItemName = null;
      _expandedItems.clear();
    });
  }

  void _toggleExpanded(String usageId) {
    setState(() {
      _expandedItems[usageId] = !(_expandedItems[usageId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Issued Items List'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: _clearFilters,
            tooltip: 'Clear Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Card
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Date Range
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today, size: 20),
                    title: Text('Date Range', style: TextStyle(fontSize: 14)),
                    subtitle: _selectedDateRange == null
                        ? Text('Select date range',
                            style: TextStyle(fontSize: 12))
                        : Text(
                            '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                            style: TextStyle(fontSize: 12),
                          ),
                    trailing: Icon(Icons.arrow_drop_down, size: 20),
                    onTap: () => _selectDateRange(context),
                  ),

                  Divider(height: 20),

                  // Washer Filter
                  StreamBuilder<List<Washer>>(
                    stream: firebaseService.getWashers(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _washers = snapshot.data!;
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedWasherId,
                        decoration: InputDecoration(
                          labelText: 'Filter by Washer',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Washers',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ..._washers.map((washer) {
                            return DropdownMenuItem(
                              value: washer.id,
                              child: Text(washer.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedWasherId = value;
                          });
                        },
                      );
                    },
                  ),

                  SizedBox(height: 12),

                  // Item Name Filter
                  StreamBuilder<List<EquipmentUsage>>(
                    stream: firebaseService.getEquipmentUsageByDateRange(
                        DateTime(2020),
                        DateTime.now().add(Duration(days: 365))),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _itemNames = snapshot.data!
                            .map((usage) => usage.storeItemName)
                            .toSet()
                            .toList();
                        _itemNames.sort();
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedItemName,
                        decoration: InputDecoration(
                          labelText: 'Filter by Item',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Items',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ..._itemNames.map((itemName) {
                            return DropdownMenuItem(
                              value: itemName,
                              child: Text(itemName),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedItemName = value;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Issued Items List
          Expanded(
            child: _buildIssuedItemsList(firebaseService),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuedItemsList(FirebaseService firebaseService) {
    if (_selectedDateRange == null) {
      return Center(child: Text('Please select date range'));
    }

    return StreamBuilder<List<EquipmentUsage>>(
      stream: firebaseService.getEquipmentUsageByDateRange(
          _selectedDateRange!.start, _selectedDateRange!.end),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        var issuedItems = snapshot.data ?? [];

        // Apply filters
        if (_selectedWasherId != null) {
          issuedItems = issuedItems
              .where((item) => item.washerId == _selectedWasherId)
              .toList();
        }

        if (_selectedItemName != null) {
          issuedItems = issuedItems
              .where((item) => item.storeItemName == _selectedItemName)
              .toList();
        }

        if (issuedItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No issued items found'),
                SizedBox(height: 8),
                Text('Try adjusting your filters'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: issuedItems.length,
          itemBuilder: (context, index) {
            final item = issuedItems[index];
            final isExpanded = _expandedItems[item.id] ?? false;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ExpansionTile(
                key: Key(item.id),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) => _toggleExpanded(item.id),
                leading: Icon(
                  item.isPaid ? Icons.check_circle : Icons.pending,
                  color: item.isPaid ? Colors.green : Colors.orange,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.storeItemName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            item.washerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ETB ${item.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Text(DateFormat('MMM dd').format(item.date)),
                    SizedBox(width: 8),
                    Icon(Icons.access_time, size: 12),
                    SizedBox(width: 4),
                    Text(DateFormat('HH:mm').format(item.date)),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Item Name', item.storeItemName),
                        _buildDetailRow('Washer', item.washerName),
                        _buildDetailRow('Quantity', item.quantity.toString()),
                        _buildDetailRow('Unit Price',
                            'ETB ${item.unitPrice.toStringAsFixed(0)}'),
                        _buildDetailRow('Total Amount',
                            'ETB ${item.totalAmount.toStringAsFixed(0)}'),
                        _buildDetailRow('Date',
                            DateFormat('MMM dd, yyyy').format(item.date)),
                        _buildDetailRow(
                            'Time', DateFormat('HH:mm').format(item.date)),
                        _buildDetailRow(
                            'Status', item.isPaid ? 'Paid' : 'Unpaid'),
                        if (item.isPaid && item.paidDate != null)
                          _buildDetailRow(
                              'Paid Date',
                              DateFormat('MMM dd, yyyy - HH:mm')
                                  .format(item.paidDate!)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
