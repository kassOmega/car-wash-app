import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class CustomerManagement extends StatefulWidget {
  @override
  _CustomerManagementState createState() => _CustomerManagementState();
}

class _CustomerManagementState extends State<CustomerManagement> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedType = 'Regular';

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

      await firebaseService.addCustomer(customer);

      _nameController.clear();
      _phoneController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer added successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isOwner && !authProvider.isCashier) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text('You do not have permission to access this feature.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Customer Management'),
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
                    Text('Add New Customer',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Customer Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Regular', 'VIP', 'Corporate'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addCustomer,
                      child: Text('Add Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: firebaseService.getCustomers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final customers = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.people, color: Colors.green),
                          title: Text(customer.name),
                          subtitle: Text(
                              '${customer.phone} • ${customer.customerType}'),
                          trailing: Text(
                            customer.registrationDate.toString().split(' ')[0],
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
    );
  }
}
