import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/customer.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class CarWashEntry extends StatefulWidget {
  const CarWashEntry({super.key});

  @override
  _CarWashEntryState createState() => _CarWashEntryState();
}

class _CarWashEntryState extends State<CarWashEntry> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedWasherId;
  String _vehicleType = 'Car';
  String _notes = '';

  List<Customer> _customers = [];
  List<Washer> _washers = [];

  // Stream subscriptions
  late final Stream<List<Customer>> _customerStream;
  late final Stream<List<Washer>> _washerStream;

  @override
  void initState() {
    super.initState();
    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);

    // Initialize streams for customers and washers
    _customerStream = firebaseService.getCustomers();
    _washerStream = firebaseService.getWashers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitCarWash() async {
    if (_formKey.currentState!.validate() && _selectedWasherId != null) {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final currentUserId = authProvider.user?.uid;

      final carWash = CarWash(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: _selectedCustomerId,
        washerId: _selectedWasherId!,
        vehicleType: _vehicleType,
        amount: amount,
        date: DateTime.now(),
        notes: _notes.isNotEmpty ? _notes : null,
        recordedBy: currentUserId,
      );

      try {
        await firebaseService.addCarWash(carWash);

        // Clear form
        _amountController.clear();
        setState(() {
          _selectedCustomerId = null;
          _selectedWasherId = _washers.isNotEmpty ? _washers.first.id : null;
          _vehicleType = 'Car';
          _notes = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Car Wash recorded successfully!')),
        );
      } catch (e) {
        print('Error recording car wash: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record car wash: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Car Wash'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Customer Selection ---
              StreamBuilder<List<Customer>>(
                stream: _customerStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Text('Loading Customers...'));
                  }

                  _customers = snapshot.data ?? [];

                  return DropdownButtonFormField<String?>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: 'Customer (Optional)',
                      prefixIcon: Icon(Icons.person, color: Colors.teal),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Walk-in Customer')),
                      ..._customers.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.phone})'),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCustomerId = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- Washer Selection ---
              StreamBuilder<List<Washer>>(
                stream: _washerStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Text('Loading Washers...'));
                  }

                  _washers =
                      snapshot.data?.where((w) => w.isActive).toList() ?? [];

                  // Set default selected washer if not set and list is available
                  if (_selectedWasherId == null && _washers.isNotEmpty) {
                    _selectedWasherId = _washers.first.id;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedWasherId,
                    decoration: const InputDecoration(
                      labelText: 'Washer (Required)',
                      prefixIcon:
                          Icon(Icons.cleaning_services, color: Colors.orange),
                    ),
                    items: _washers
                        .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(
                                  '${w.name} (${w.percentage.toStringAsFixed(0)}% Commission)'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWasherId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a washer';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- Vehicle Type Selection ---
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  prefixIcon: Icon(Icons.local_shipping, color: Colors.blue),
                ),
                items: <String>['Car', 'Truck', 'Van', 'Motorcycle', 'Other']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _vehicleType = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // --- Amount Entry ---
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (\$)',
                  prefixIcon: Icon(Icons.attach_money, color: Colors.green),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Notes ---
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Notes (Optional)'),
                maxLines: 2,
                onChanged: (value) {
                  _notes = value;
                },
              ),
              const SizedBox(height: 24),

              // --- Submit Button ---
              ElevatedButton(
                onPressed: _submitCarWash,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Record Car Wash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
