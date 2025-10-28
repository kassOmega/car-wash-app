import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/price.dart';
import '../services/firebase_service.dart';

class PricesListScreen extends StatefulWidget {
  @override
  _PricesListScreenState createState() => _PricesListScreenState();
}

class _PricesListScreenState extends State<PricesListScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize default prices if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePrices();
    });
  }

  Future<void> _initializePrices() async {
    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);
    final prices = await firebaseService.getPrices().first;

    if (prices.isEmpty) {
      await firebaseService.initializeDefaultPrices();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  TextEditingController _getController(
      String vehicleType, double currentAmount) {
    if (!_controllers.containsKey(vehicleType)) {
      _controllers[vehicleType] =
          TextEditingController(text: currentAmount.toStringAsFixed(0));
    }
    return _controllers[vehicleType]!;
  }

  Future<void> _updatePrice(String vehicleType, double newAmount) async {
    if (newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount must be greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final price = Price(vehicleType: vehicleType, amount: newAmount);
      await firebaseService.updatePrice(price);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Price updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating price: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Prices'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Price>>(
        stream: Provider.of<FirebaseService>(context).getPrices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final prices = snapshot.data ?? [];

          if (prices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No prices found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializePrices,
                    child: Text('Initialize Default Prices'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: prices.length,
            itemBuilder: (context, index) {
              final price = prices[index];
              final controller =
                  _getController(price.vehicleType, price.amount);

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          price.vehicleType,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                            prefixText: 'TZS ',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          onFieldSubmitted: (value) {
                            final newAmount = double.tryParse(value) ?? 0;
                            _updatePrice(price.vehicleType, newAmount);
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.save, color: Colors.blue),
                        onPressed: () {
                          final newAmount =
                              double.tryParse(controller.text) ?? 0;
                          _updatePrice(price.vehicleType, newAmount);
                        },
                        tooltip: 'Save Price',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializePrices,
        child: Icon(Icons.refresh),
        tooltip: 'Reset to Default Prices',
      ),
    );
  }
}
