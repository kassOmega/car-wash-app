import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/money_collection.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class MoneyCollectionScreen extends StatefulWidget {
  const MoneyCollectionScreen({super.key});

  @override
  _MoneyCollectionScreenState createState() => _MoneyCollectionScreenState();
}

class _MoneyCollectionScreenState extends State<MoneyCollectionScreen> {
  final _collectedAmountController = TextEditingController();
  final _remainingAmountController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isCalculating = false;

  // Daily report data
  double _totalOwnerShare = 0.0;
  double _totalEquipmentRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _netAmountDue = 0.0;
  double _previouslyCollected = 0.0;
  double _remainingBalance = 0.0;
  double _autoTotalIncome = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDailyReport();
  }

  @override
  void dispose() {
    _collectedAmountController.dispose();
    _remainingAmountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyReport() async {
    setState(() => _isCalculating = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get selected date range
      final startOfDay =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, 23, 59, 59);

      // Fetch data for the selected date - cashiers can now read these collections
      final carWashes = await firebaseService
          .getCarWashesByDateRange(startOfDay, endOfDay)
          .first;
      final expenses = await firebaseService
          .getExpensesByDateRange(startOfDay, endOfDay)
          .first;
      final equipmentUsage = await firebaseService
          .getEquipmentUsageByDateRange(startOfDay, endOfDay)
          .first;
      final washers = await firebaseService.getWashers().first;
      final previousCollections = await firebaseService
          .getMoneyCollectionsByDateRange(startOfDay, endOfDay)
          .first;

      // Calculate owner's share from car washes
      double totalRevenue = 0.0;
      double totalWasherCommission = 0.0;

      for (final carWash in carWashes) {
        totalRevenue += carWash.amount;

        // Find washer and calculate their commission
        final washer = washers.firstWhere(
          (w) => w.id == carWash.washerId,
          orElse: () => Washer(
            id: carWash.washerId,
            name: 'Unknown Washer',
            phone: '',
            percentage: 50.0,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        totalWasherCommission += carWash.amount * (washer.percentage / 100);
      }

      _totalOwnerShare = totalRevenue - totalWasherCommission;

      // Calculate TOTAL equipment revenue (both paid and unpaid)
      _totalEquipmentRevenue =
          equipmentUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);

      // Calculate total expenses - cashiers can now read expenses for calculation
      _totalExpenses =
          expenses.fold(0.0, (sum, expense) => sum + expense.amount);

      // Calculate net amount due to owner
      _netAmountDue =
          _totalOwnerShare + _totalEquipmentRevenue - _totalExpenses;

      // Calculate previously collected amount
      _previouslyCollected = previousCollections.fold(
          0.0, (sum, collection) => sum + collection.totalAmount);

      // Calculate remaining balance
      _remainingBalance = _netAmountDue - _previouslyCollected;

      // Auto-filled total income is the remaining balance
      _autoTotalIncome = _remainingBalance;

      // Initialize controllers with calculated values
      _collectedAmountController.text = _autoTotalIncome.toStringAsFixed(0);
      _updateRemainingAmount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating daily report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isCalculating = false);
  }

  void _updateRemainingAmount() {
    final collectedAmount =
        double.tryParse(_collectedAmountController.text) ?? 0.0;
    final remainingAmount = _autoTotalIncome - collectedAmount;
    _remainingAmountController.text = remainingAmount.toStringAsFixed(0);
  }

  Future<void> _collectMoney() async {
    final collectedAmount =
        double.tryParse(_collectedAmountController.text) ?? 0.0;
    final remainingAmount =
        double.tryParse(_remainingAmountController.text) ?? 0.0;

    if (collectedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid collected amount')),
      );
      return;
    }

    if (collectedAmount > _autoTotalIncome) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collected amount cannot exceed total income')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      String notes = '';
      if (_reasonController.text.isNotEmpty) {
        notes = 'Reason for remaining: ${_reasonController.text} | ';
      }
      notes +=
          'Collected: ETB ${collectedAmount.toStringAsFixed(0)} | Remaining: ETB ${remainingAmount.toStringAsFixed(0)}';

      final collection = MoneyCollection(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        collectedBy: authProvider.user!.uid,
        collectedByName: authProvider.appUser?.name ??
            (authProvider.isCashier ? 'Cashier' : 'Owner'),
        totalAmount: collectedAmount,
        collectionDate: _selectedDate,
        createdAt: DateTime.now(),
        notes: notes,
        dailyOwnerShare: _totalOwnerShare,
        equipmentRevenue: _totalEquipmentRevenue,
        totalExpenses: _totalExpenses,
        netAmountDue: _netAmountDue,
        remainingBalance: remainingAmount,
      );

      await firebaseService.addMoneyCollection(collection);

      // Clear form and reload data
      _reasonController.clear();
      await _loadDailyReport();

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
      _loadDailyReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Both owners and cashiers can access this screen
    if (!authProvider.isOwner && !authProvider.isCashier) {
      return Scaffold(
        appBar: AppBar(title: Text('Access Denied')),
        body: Center(child: Text('Only owners and cashiers can collect money')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Money Collection'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDailyReport,
            tooltip: 'Refresh Report',
          ),
        ],
      ),
      body: _isCalculating
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // User Role Info

                  SizedBox(height: 8),

                  // Date Selection
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text('Collection Date'),
                      subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      trailing: Icon(Icons.arrow_drop_down),
                      onTap: () => _selectDate(context),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Daily Report Summary - Both can see
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Financial Summary',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          _buildSummaryItem('Owner\'s Car Wash Share',
                              _totalOwnerShare, Colors.blue),
                          _buildSummaryItem('Total Equipment Revenue',
                              _totalEquipmentRevenue, Colors.orange),
                          _buildSummaryItem(
                              'Total Expenses', _totalExpenses, Colors.red),
                          Divider(),
                          _buildSummaryItem(
                              'Net Amount Due', _netAmountDue, Colors.green,
                              isBold: true),
                          _buildSummaryItem('Previously Collected',
                              _previouslyCollected, Colors.purple),
                          _buildSummaryItem(
                              'Available to Collect',
                              _autoTotalIncome,
                              _autoTotalIncome > 0 ? Colors.green : Colors.grey,
                              isBold: true),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Collection Form - Both can use
                  if (authProvider.isOwner)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Money Collection',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),

                            // Auto-filled Total Income (Read-only)
                            TextFormField(
                              initialValue:
                                  'ETB ${_autoTotalIncome.toStringAsFixed(0)}',
                              decoration: InputDecoration(
                                labelText: 'Total Available Income *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                filled: true,
                                fillColor: Colors.blue[50],
                              ),
                              readOnly: true,
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            SizedBox(height: 16),

                            // Collected Amount (Editable)
                            TextFormField(
                              controller: _collectedAmountController,
                              decoration: InputDecoration(
                                labelText: 'Amount Actually Collected *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.money),
                                hintText: 'Enter the amount you collected',
                                suffixText: 'ETB',
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (value) => _updateRemainingAmount(),
                            ),

                            SizedBox(height: 16),

                            // Auto-calculated Remaining Amount (Read-only)
                            TextFormField(
                              controller: _remainingAmountController,
                              decoration: InputDecoration(
                                labelText: 'Remaining Amount',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.pending),
                                filled: true,
                                fillColor: Colors.orange[50],
                              ),
                              readOnly: true,
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            SizedBox(height: 16),

                            // Reason for Remaining Amount
                            TextFormField(
                              controller: _reasonController,
                              decoration: InputDecoration(
                                labelText:
                                    'Reason for Remaining Amount (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note),
                                hintText:
                                    'e.g., Customer will pay tomorrow, partial payment received, etc...',
                              ),
                              maxLines: 3,
                            ),

                            SizedBox(height: 16),

                            // Collection Summary
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Available:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          'ETB ${_autoTotalIncome.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Collected:',
                                          style:
                                              TextStyle(color: Colors.green)),
                                      Text(
                                          'ETB ${(double.tryParse(_collectedAmountController.text) ?? 0.0).toStringAsFixed(0)}',
                                          style:
                                              TextStyle(color: Colors.green)),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Remaining:',
                                          style:
                                              TextStyle(color: Colors.orange)),
                                      Text(
                                          'ETB ${(double.tryParse(_remainingAmountController.text) ?? 0.0).toStringAsFixed(0)}',
                                          style:
                                              TextStyle(color: Colors.orange)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24),

                            // Collect Button
                            ElevatedButton(
                              onPressed: (_isLoading || _autoTotalIncome <= 0)
                                  ? null
                                  : _collectMoney,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: _isLoading
                                  ? CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text('Record Collection'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: 20),

                  // Recent Collections - Both can see
                  if (authProvider.isOwner) _buildRecentCollections(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'ETB ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCollections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Collections',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          height: 300,
          child: StreamBuilder<List<MoneyCollection>>(
            stream: Provider.of<FirebaseService>(context).getMoneyCollections(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final collections = snapshot.data ?? [];

              if (collections.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet,
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
                          'ETB ${collection.totalAmount.toStringAsFixed(0)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Collected by: ${collection.collectedByName}'),
                          Text(DateFormat('MMM dd, yyyy')
                              .format(collection.collectionDate)),
                          if (collection.remainingBalance != null &&
                              collection.remainingBalance! > 0)
                            Text(
                              'Remaining: ETB ${collection.remainingBalance!.toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold),
                            ),
                          if (collection.notes != null)
                            Text('${collection.notes!}',
                                style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Text(
                        DateFormat('HH:mm').format(collection.createdAt),
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
    );
  }
}
