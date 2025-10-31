import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/equipment_usage.dart';
import '../models/store_item.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
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
  bool _isDeleting = false;
  String? _deletingUsageId;

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final selectedWasher =
          _washers.firstWhere((w) => w.id == _selectedWasherId);
      final selectedItem = _items.firstWhere((i) => i.id == _selectedItemId);

      // Check stock availability
      if (selectedItem.currentStock < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Insufficient stock. Available: ${selectedItem.currentStock}'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
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
        isPaid: false,
      );

      await firebaseService.addEquipmentUsage(usage);

      // Clear form
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
      String errorMessage = 'Error recording usage: $e';

      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage =
            'Permission denied. Cashiers can register issued items but cannot delete them. '
            'Please contact owner if you need additional permissions.';
      } else if (e.toString().contains('not-found')) {
        errorMessage =
            'Item or washer not found. Please refresh and try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteUsage(EquipmentUsage usage) async {
    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Issued Item'),
          content: Text(
            'Are you sure you want to delete this issued item record?\n\n'
            '${usage.quantity} × ${usage.storeItemName} for ${usage.washerName}\n'
            'Amount: ETB ${usage.totalAmount.toStringAsFixed(0)}\n\n'
            'This will restore ${usage.quantity} items back to stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete Record', // FIX 2: Updated button text
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() {
        _isDeleting = true;
        _deletingUsageId = usage.id;
      });

      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);

        // Delete the usage record and restore stock
        await _deleteEquipmentUsageWithStockRestore(firebaseService, usage);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issued item deleted successfully! Stock restored.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting issued item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isDeleting = false;
          _deletingUsageId = null;
        });
      }
    }
  }

  Future<void> _deleteEquipmentUsageWithStockRestore(
      FirebaseService firebaseService, EquipmentUsage usage) async {
    final batch = FirebaseFirestore.instance.batch();

    // Delete the usage record
    final usageRef =
        FirebaseFirestore.instance.collection('equipment_usage').doc(usage.id);
    batch.delete(usageRef);

    // Restore stock to the store item
    final itemRef = FirebaseFirestore.instance
        .collection('store_items')
        .doc(usage.storeItemId);
    batch.update(itemRef, {
      'currentStock': FieldValue.increment(usage.quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Add this method to your FirebaseService class or use it directly
  Future<void> _markAsPaid(EquipmentUsage usage) async {
    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.markEquipmentUsageAsPaid(usage.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment marked as paid!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking as paid: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Record Issued Items'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_isDeleting)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Record New Usage Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Outstanding Issued Items Payments',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (_isDeleting)
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Deleting...',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                    ],
                  ),
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
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Colors.green),
                                SizedBox(height: 16),
                                Text(
                                  'All payments are cleared!',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.green),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No outstanding payments',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
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
                                    ...usages.map((usage) {
                                      final isDeletingThisUsage = _isDeleting &&
                                          _deletingUsageId == usage.id;

                                      return ListTile(
                                        dense: true,
                                        leading: isDeletingThisUsage
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : Icon(Icons.inventory_2, size: 20),
                                        title: Text(usage.storeItemName),
                                        subtitle: Text(
                                            'Qty: ${usage.quantity} × ETB ${usage.unitPrice.toStringAsFixed(0)}'),
                                        trailing: isDeletingThisUsage
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                      'ETB ${usage.totalAmount.toStringAsFixed(0)}'),
                                                  SizedBox(width: 8),
                                                  // Delete button for individual items - FIX 1: Only show for owners
                                                  if (authProvider.isOwner)
                                                    IconButton(
                                                      icon: Icon(Icons.delete,
                                                          size: 18,
                                                          color: Colors.red),
                                                      onPressed: _isDeleting
                                                          ? null
                                                          : () => _deleteUsage(
                                                              usage),
                                                      tooltip:
                                                          'Delete this item',
                                                    ),
                                                ],
                                              ),
                                      );
                                    }),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Mark all as paid button
                                        ElevatedButton(
                                          onPressed: _isDeleting
                                              ? null
                                              : () async {
                                                  for (final usage in usages) {
                                                    await _markAsPaid(usage);
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('Mark All as Paid'),
                                        ),
                                        SizedBox(width: 8),
                                        // Delete all button - FIX 1: Only show for owners
                                        if (authProvider.isOwner)
                                          ElevatedButton(
                                            onPressed: _isDeleting
                                                ? null
                                                : () async {
                                                    for (final usage
                                                        in usages) {
                                                      await _deleteUsage(usage);
                                                    }
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(
                                                'Delete All Records'), // FIX 2: Updated button text
                                          ),
                                      ],
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
