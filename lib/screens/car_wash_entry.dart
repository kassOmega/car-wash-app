import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/customer.dart';
import '../models/price.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'prices_list_screen.dart';

class CarWashEntry extends StatefulWidget {
  @override
  _CarWashEntryState createState() => _CarWashEntryState();
}

class _CarWashEntryState extends State<CarWashEntry> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedWasherId;
  String _vehicleType = 'Car';
  List<Price> _prices = [];

  List<Customer> _customers = [];
  List<Washer> _washers = [];

  @override
  void initState() {
    super.initState();
    // Initialize default vehicle type amount
    _updateAmountForVehicleType(_vehicleType);
  }

  Future<void> _updateAmountForVehicleType(String vehicleType) async {
    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);
    final price = await firebaseService.getPriceByVehicleType(vehicleType);

    if (price != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _amountController.text = price.amount.toStringAsFixed(0);
      });
    }
  }

  Future<void> _submitCarWash() async {
    if (_formKey.currentState!.validate() && _selectedWasherId != null) {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final carWash = CarWash(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: _selectedCustomerId,
        washerId: _selectedWasherId!,
        vehicleType: _vehicleType,
        amount: amount,
        date: DateTime.now(),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        recordedBy: authProvider.user?.email ?? authProvider.appUser?.name,
        plateNumber: _plateNumberController.text.isNotEmpty
            ? _plateNumberController.text
            : null,
      );

      try {
        await firebaseService.addCarWash(carWash);

        // Clear form but keep vehicle type
        _amountController.clear();
        _plateNumberController.clear();
        _notesController.clear();
        setState(() {
          _selectedCustomerId = null;
          _selectedWasherId = null;
        });

        // Update amount for current vehicle type after clear
        _updateAmountForVehicleType(_vehicleType);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Car wash recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording car wash: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _amountController.clear();
    _plateNumberController.clear();
    _notesController.clear();
    setState(() {
      _selectedCustomerId = null;
      _selectedWasherId = null;
      _vehicleType = 'Car';
    });
    // Update amount for default vehicle type
    _updateAmountForVehicleType(_vehicleType);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Record Car Wash'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: _clearForm,
            tooltip: 'Clear Form',
          ),
          if (authProvider.isOwner)
            IconButton(
              icon: Icon(Icons.attach_money),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PricesListScreen()),
                );
              },
              tooltip: 'Manage Prices',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Customer Selection (Owners and Cashiers only)
              if (authProvider.isOwner || authProvider.isCashier) ...[
                StreamBuilder<List<Customer>>(
                  stream: firebaseService.getCustomers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        decoration: InputDecoration(
                          labelText: 'Loading customers...',
                          border: OutlineInputBorder(),
                        ),
                        items: [],
                        onChanged: (value) {},
                      );
                    }

                    _customers = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      decoration: InputDecoration(
                        labelText: 'Customer (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('No Customer - Walk-in'),
                        ),
                        ..._customers.map((customer) {
                          return DropdownMenuItem<String>(
                            value: customer.id,
                            child: Text(customer.name),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCustomerId = value;
                        });
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
              ],

              // Washer Selection
              StreamBuilder<List<Washer>>(
                stream: firebaseService.getWashers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      value: null,
                      decoration: InputDecoration(
                        labelText: 'Loading washers...',
                        border: OutlineInputBorder(),
                        errorText: 'Please select a washer',
                      ),
                      items: [],
                      onChanged: (value) {},
                    );
                  }

                  _washers = snapshot.data ?? [];

                  if (_washers.isEmpty) {
                    return Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No washers available. Please add washers first.',
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                    );
                  }

                  final uniqueWashers = _washers
                      .fold<Map<String, Washer>>({}, (map, washer) {
                        if (!map.containsKey(washer.id)) {
                          map[washer.id] = washer;
                        }
                        return map;
                      })
                      .values
                      .toList();

                  if (_selectedWasherId != null &&
                      !uniqueWashers
                          .any((washer) => washer.id == _selectedWasherId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _selectedWasherId = null;
                      });
                    });
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedWasherId,
                    decoration: InputDecoration(
                      labelText: 'Washer *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_car_wash),
                      errorText: _selectedWasherId == null
                          ? 'Please select a washer'
                          : null,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        enabled: false,
                        child: Text('Select a washer',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ...uniqueWashers.map((washer) {
                        return DropdownMenuItem<String>(
                          value: washer.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(washer.name),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedWasherId = value;
                        });
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Please select a washer' : null,
                  );
                },
              ),
              SizedBox(height: 16),

              // Vehicle Type with auto-price
              StreamBuilder<List<Price>>(
                stream: firebaseService.getPrices(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _prices = snapshot.data!;
                  }

                  return DropdownButtonFormField<String>(
                    value: _vehicleType,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    items: _prices.map((price) {
                      return DropdownMenuItem<String>(
                        value: price.vehicleType,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(price.vehicleType),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _vehicleType = value!;
                      });
                      // Update amount when vehicle type changes
                      _updateAmountForVehicleType(value!);
                    },
                  );
                },
              ),
              SizedBox(height: 16),

              // Plate Number Field
              TextFormField(
                controller: _plateNumberController,
                decoration: InputDecoration(
                  labelText: 'Plate Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              SizedBox(height: 16),

              // Amount (auto-filled but editable)
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () {
                      // Reset to default price for current vehicle type
                      _updateAmountForVehicleType(_vehicleType);
                    },
                    tooltip: 'Reset to default price',
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Please enter valid amount';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
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

              // Submit Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitCarWash,
                      child: Text(
                        'Record Car Wash',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),

              // Quick Add Another Button
              SizedBox(height: 12),
              OutlinedButton(
                onPressed: _submitCarWash,
                child: Text('Save and Add Another'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _plateNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
