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
  final TextEditingController _newVehicleTypeController =
      TextEditingController();
  final TextEditingController _newVehiclePriceController =
      TextEditingController();
  bool _showAddForm = false;

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
    _newVehicleTypeController.dispose();
    _newVehiclePriceController.dispose();
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

  Future<void> _addNewVehicleType() async {
    final vehicleType = _newVehicleTypeController.text.trim();
    final priceText = _newVehiclePriceController.text.trim();

    if (vehicleType.isEmpty) {
      _showErrorSnackBar('Please enter vehicle type');
      return;
    }

    if (priceText.isEmpty) {
      _showErrorSnackBar('Please enter price');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      _showErrorSnackBar('Please enter a valid price greater than 0');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      // Check if vehicle type already exists
      final existingPrice =
          await firebaseService.getPriceByVehicleType(vehicleType);
      if (existingPrice != null) {
        _showErrorSnackBar('Vehicle type "$vehicleType" already exists');
        return;
      }

      // Add new vehicle type
      final newPrice = Price(vehicleType: vehicleType, amount: price);
      await firebaseService.addPrice(newPrice);

      _showSuccessSnackBar(
          'New vehicle type "$vehicleType" added successfully!');

      // Clear form and hide it
      _newVehicleTypeController.clear();
      _newVehiclePriceController.clear();
      setState(() => _showAddForm = false);
    } catch (e) {
      _showErrorSnackBar('Error adding new vehicle type: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVehicleType(String vehicleType) async {
    final shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Vehicle Type'),
        content: Text(
            'Are you sure you want to delete "$vehicleType"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);

      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);
        await firebaseService.deletePrice(vehicleType);

        _showSuccessSnackBar(
            'Vehicle type "$vehicleType" deleted successfully');

        // Remove controller
        _controllers.remove(vehicleType);
      } catch (e) {
        _showErrorSnackBar('Error deleting vehicle type: $e');
      } finally {
        setState(() => _isLoading = false);
      }
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

  Widget _buildAddNewVehicleForm() {
    return Card(
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Add New Vehicle Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _newVehicleTypeController,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Truck, Van, SUV',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _newVehiclePriceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: 'ETB ',
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _addNewVehicleType,
                      child: Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        setState(() => _showAddForm = false);
                        _newVehicleTypeController.clear();
                        _newVehiclePriceController.clear();
                      },
                      child: Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
              icon: Icon(Icons.save_alt),
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

                return Column(
                  children: [
                    // Add New Vehicle Form
                    if (_showAddForm) _buildAddNewVehicleForm(),

                    // Header with buttons
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vehicle Type Prices (${prices.length})',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!_showAddForm)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => _showAddForm = true),
                              icon: Icon(Icons.add, size: 16),
                              label: Text('Add New'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _updateAllPrices,
                            icon: Icon(Icons.save_alt, size: 16),
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
                      child: prices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.money_off,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No prices found',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _initializePrices,
                                    child: Text('Initialize Default Prices'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              itemCount: prices.length,
                              itemBuilder: (context, index) {
                                final price = prices[index];
                                final controller = _getController(
                                    price.vehicleType, price.amount);

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
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        IconButton(
                                          icon: Icon(Icons.save,
                                              color: Colors.blue),
                                          onPressed: () {
                                            final newAmount = double.tryParse(
                                                    controller.text) ??
                                                0;
                                            _updatePrice(
                                                price.vehicleType, newAmount);
                                          },
                                          tooltip: 'Save This Price',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => _deleteVehicleType(
                                              price.vehicleType),
                                          tooltip: 'Delete Vehicle Type',
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_showAddForm)
            FloatingActionButton(
              onPressed: () => setState(() => _showAddForm = true),
              child: Icon(Icons.add),
              tooltip: 'Add New Vehicle Type',
              backgroundColor: Colors.blue,
              mini: true,
            ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _resetToDefaultPrices,
            child: Icon(Icons.refresh),
            tooltip: 'Reset to Default Prices',
            backgroundColor: Colors.amber[700],
          ),
        ],
      ),
    );
  }
}
