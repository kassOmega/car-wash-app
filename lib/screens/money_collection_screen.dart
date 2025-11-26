import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/money_collection.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class MoneyCollectionScreen extends StatefulWidget {
  const MoneyCollectionScreen({super.key});

  @override
  _MoneyCollectionScreenState createState() => _MoneyCollectionScreenState();
}

class _MoneyCollectionScreenState extends State<MoneyCollectionScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _collectMoney() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if money already collected for this date
      final alreadyCollected =
          await firebaseService.getTotalCollectedForDate(_selectedDate);
      if (alreadyCollected > 0) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Money Already Collected'),
            content: Text(
                'Money has already been collected for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}. Do you want to add another collection?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Add Another'),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final collection = MoneyCollection(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        collectedBy: authProvider.user!.uid,
        collectedByName: authProvider.appUser?.name ?? 'Owner',
        totalAmount: amount,
        collectionDate: _selectedDate,
        createdAt: DateTime.now(),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await firebaseService.addMoneyCollection(collection);

      // Clear form
      _amountController.clear();
      _notesController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Money collection recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording collection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isOwner) {
      return Scaffold(
        appBar: AppBar(title: Text('Access Denied')),
        body: Center(child: Text('Only owners can collect money')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Money Collection'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Collection Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Record Money Collection',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),

                    // Date Selection
                    ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text('Collection Date'),
                      subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      trailing: Icon(Icons.arrow_drop_down),
                      onTap: () => _selectDate(context),
                    ),

                    SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount Collected *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                    ),

                    SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),

                    SizedBox(height: 24),

                    // Collect Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _collectMoney,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Record Collection'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Recent Collections
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Collections',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<List<MoneyCollection>>(
                      stream: Provider.of<FirebaseService>(context)
                          .getMoneyCollections(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final collections = snapshot.data ?? [];

                        if (collections.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_off,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No collections recorded'),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: collections.length,
                          itemBuilder: (context, index) {
                            final collection = collections[index];
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Icon(Icons.account_balance_wallet,
                                    color: Colors.green),
                                title: Text(
                                    'ETB ${collection.totalAmount.toStringAsFixed(2)}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Collected by: ${collection.collectedByName}'),
                                    Text(DateFormat('MMM dd, yyyy')
                                        .format(collection.collectionDate)),
                                    if (collection.notes != null)
                                      Text('Notes: ${collection.notes!}'),
                                  ],
                                ),
                                trailing: Text(
                                  DateFormat('HH:mm')
                                      .format(collection.createdAt),
                                  style: TextStyle(color: Colors.grey),
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

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
