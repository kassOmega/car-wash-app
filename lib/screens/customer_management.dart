import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class CustomerManagement extends StatefulWidget {
  const CustomerManagement({super.key});

  @override
  _CustomerManagementState createState() => _CustomerManagementState();
}

class _CustomerManagementState extends State<CustomerManagement> {
  // Controllers and state for the form
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedType = 'Regular';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addCustomer() async {
    if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      final customer = Customer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        phone: _phoneController.text,
        customerType: _selectedType,
        registrationDate: DateTime.now(),
      );

      try {
        await firebaseService.addCustomer(customer);

        _nameController.clear();
        _phoneController.clear();
        _selectedType = 'Regular'; // Reset type

        // Close the dialog after successful add
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer added successfully!')),
        );
      } catch (e) {
        print('Error adding customer: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add customer: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name and phone.')),
      );
    }
  }

  // Dialog to show the Add form
  void _showCustomerForm() {
    // Reset state for the form before showing
    _nameController.clear();
    _phoneController.clear();
    _selectedType = 'Regular';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Customer'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: 'Customer Type'),
                      value: _selectedType,
                      items: <String>['Regular', 'VIP', 'Company']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _selectedType = newValue!;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addCustomer,
              child: const Text('Add Customer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Only Owners/Cashiers can access this
    if (!authProvider.isOwner && !authProvider.isCashier) {
      return const Center(
          child: Text('Access Denied. Owner/Cashier permission required.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Management'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'View and register new customers.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: firebaseService.getCustomers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final customers = snapshot.data ?? [];

                  if (customers.isEmpty) {
                    return const Center(
                        child: Text('No customers registered yet.'));
                  }

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.people,
                              color: Colors.teal, size: 30),
                          title: Text(customer.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${customer.phone} • ${customer.customerType}'),
                          trailing: Text(
                            customer.registrationDate.toString().split(' ')[0],
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCustomerForm,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
