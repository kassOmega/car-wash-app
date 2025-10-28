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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePrices();
    });
  }

  Future<void> _initializePrices() async {
    setState(() => _isLoading = true);
    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final prices = await firebaseService.getPrices().first;

      if (prices.isEmpty) {
        await firebaseService.initializeDefaultPrices();
      }
    } catch (e) {
      _showErrorSnackBar('Error initializing prices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
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
      _showErrorSnackBar('Amount must be greater than 0');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.updatePriceByVehicleType(vehicleType, newAmount);

      _showSuccessSnackBar('Price updated for $vehicleType');
    } catch (e) {
      _showErrorSnackBar('Error updating price: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAllPrices() async {
    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final priceUpdates = <String, double>{};

      _controllers.forEach((vehicleType, controller) {
        final amount = double.tryParse(controller.text) ?? 0;
        if (amount > 0) {
          priceUpdates[vehicleType] = amount;
        }
      });

      if (priceUpdates.isNotEmpty) {
        await firebaseService.updateMultiplePrices(priceUpdates);
        _showSuccessSnackBar('All prices updated successfully!');
      } else {
        _showErrorSnackBar('No valid prices to update');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating prices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToDefaultPrices() async {
    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.resetToDefaultPrices();
      _showSuccessSnackBar('Prices reset to default values');

      // Clear controllers to force refresh
      _controllers.clear();
      setState(() {});
    } catch (e) {
      _showErrorSnackBar('Error resetting prices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Prices'),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons
                  .save_alt), // CORRECTED: Changed from save_all to save_alt
              onPressed: _updateAllPrices,
              tooltip: 'Save All Prices',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Price>>(
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

                return Column(
                  children: [
                    // Header with update all button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vehicle Type Prices',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _updateAllPrices,
                            icon: Icon(Icons.save_alt,
                                size:
                                    16), // CORRECTED: Changed from save_all to save_alt
                            label: Text('Save All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Prices list
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
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
                                        prefixText: 'ETB ',
                                      ),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (value) {
                                        // You can add real-time validation here
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  IconButton(
                                    icon: Icon(Icons.save, color: Colors.blue),
                                    onPressed: () {
                                      final newAmount =
                                          double.tryParse(controller.text) ?? 0;
                                      _updatePrice(
                                          price.vehicleType, newAmount);
                                    },
                                    tooltip: 'Save This Price',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _resetToDefaultPrices,
        child: Icon(Icons.refresh),
        tooltip: 'Reset to Default Prices',
        backgroundColor: Colors.amber[700],
      ),
    );
  }
}
