import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/equipment_usage.dart';
import '../models/store_item.dart';
import '../models/washer.dart';
import '../services/firebase_service.dart';

class EquipmentUsageScreen extends StatefulWidget {
  const EquipmentUsageScreen({super.key});

  @override
  _EquipmentUsageScreenState createState() => _EquipmentUsageScreenState();
}

class _EquipmentUsageScreenState extends State<EquipmentUsageScreen> {
  final _quantityController = TextEditingController();
  String? _selectedWasherId;
  String? _selectedItemId;
  bool _isLoading = false;

  List<Washer> _washers = [];
  List<StoreItem> _items = [];

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _recordUsage() async {
    if (_selectedWasherId == null ||
        _selectedItemId == null ||
        _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please fill all fields'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please enter valid quantity'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      final selectedWasher =
          _washers.firstWhere((w) => w.id == _selectedWasherId);
      final selectedItem = _items.firstWhere((i) => i.id == _selectedItemId);

      if (selectedItem.currentStock < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Insufficient stock. Available: ${selectedItem.currentStock}'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final usage = EquipmentUsage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        washerId: selectedWasher.id,
        washerName: selectedWasher.name,
        storeItemId: selectedItem.id,
        storeItemName: selectedItem.name,
        quantity: quantity,
        unitPrice: selectedItem.sellingPrice,
        totalAmount: selectedItem.sellingPrice * quantity,
        date: DateTime.now(),
      );

      await firebaseService.addEquipmentUsage(usage);

      _quantityController.clear();
      setState(() {
        _selectedWasherId = null;
        _selectedItemId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Issued Items recorded successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error recording usage: $e'),
            backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Record Issued Items'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Record Issued Items',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),

                    // Washer Selection
                    StreamBuilder<List<Washer>>(
                      stream: firebaseService.getWashers(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          _washers = snapshot.data!;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedWasherId,
                          decoration: InputDecoration(labelText: 'Washer *'),
                          items: _washers.map((washer) {
                            return DropdownMenuItem(
                              value: washer.id,
                              child: Text(washer.name),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedWasherId = value),
                        );
                      },
                    ),
                    SizedBox(height: 16),

                    // Item Selection
                    StreamBuilder<List<StoreItem>>(
                      stream: firebaseService.getStoreItems(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          _items = snapshot.data!;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedItemId,
                          decoration: InputDecoration(labelText: 'Item *'),
                          items: _items.map((item) {
                            return DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                  '${item.name} (Stock: ${item.currentStock})'),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedItemId = value),
                        );
                      },
                    ),
                    SizedBox(height: 16),

                    // Quantity
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(labelText: 'Quantity *'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 24),

                    // Record Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _recordUsage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator()
                          : Text('Record Usage'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Outstanding Payments Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outstanding Issued Items Payments',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<List<EquipmentUsage>>(
                      stream: firebaseService.getUnpaidEquipmentUsage(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final unpaidUsages = snapshot.data ?? [];

                        if (unpaidUsages.isEmpty) {
                          return Center(child: Text('No outstanding payments'));
                        }

                        // Group by washer
                        final Map<String, List<EquipmentUsage>>
                            groupedByWasher = {};
                        for (final usage in unpaidUsages) {
                          if (!groupedByWasher.containsKey(usage.washerId)) {
                            groupedByWasher[usage.washerId] = [];
                          }
                          groupedByWasher[usage.washerId]!.add(usage);
                        }

                        return ListView.builder(
                          itemCount: groupedByWasher.length,
                          itemBuilder: (context, index) {
                            final washerId =
                                groupedByWasher.keys.elementAt(index);
                            final usages = groupedByWasher[washerId]!;
                            final washerName = usages.first.washerName;
                            final totalAmount = usages.fold(
                                0.0, (sum, usage) => sum + usage.totalAmount);

                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(washerName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            'ETB ${totalAmount.toStringAsFixed(0)}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                      ],
                                    ),
                                    ...usages.map((usage) => ListTile(
                                          dense: true,
                                          leading:
                                              Icon(Icons.inventory_2, size: 20),
                                          title: Text(usage.storeItemName),
                                          subtitle: Text(
                                              'Qty: ${usage.quantity} × ETB ${usage.unitPrice.toStringAsFixed(0)}'),
                                          trailing: Text(
                                              'ETB ${usage.totalAmount.toStringAsFixed(0)}'),
                                        )),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          for (final usage in usages) {
                                            await firebaseService
                                                .markEquipmentUsageAsPaid(
                                                    usage.id);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Mark as Paid'),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
