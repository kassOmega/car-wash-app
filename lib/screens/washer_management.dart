import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/washer.dart';
import '../services/firebase_service.dart';
import 'edit_washer_screen.dart'; // Make sure to import the edit screen

class WasherManagement extends StatefulWidget {
  @override
  _WasherManagementState createState() => _WasherManagementState();
}

class _WasherManagementState extends State<WasherManagement> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  double _percentage = 50.0;

  Future<void> _addWasher() async {
    if (_nameController.text.isNotEmpty) {
      // Only name is required now
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      // Generate a proper ID
      final washerId = DateTime.now().millisecondsSinceEpoch.toString();

      final washer = Washer(
        id: washerId,
        name: _nameController.text,
        phone: _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null, // Optional phone
        percentage: _percentage,
        createdAt: DateTime.now(),
      );

      try {
        await firebaseService.addWasher(washer);

        _nameController.clear();
        _phoneController.clear();
        setState(() {
          _percentage = 50.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washer added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding washer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter at least a name!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteWasher(Washer washer) async {
    // Validate washer ID before attempting deletion
    if (washer.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Invalid washer ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Washer'),
          content: Text(
            'Are you sure you want to delete ${washer.name}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);

        // Double-check ID before deletion
        if (washer.id.isNotEmpty) {
          await firebaseService.deleteWasher(washer.id);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Washer deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Washer ID is empty');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting washer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Washer Management'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Washer Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Add New Washer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commission Percentage: ${_percentage.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _percentage,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (value) {
                            setState(() {
                              _percentage = value;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addWasher,
                      child: Text('Add Washer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Washers List
            Expanded(
              child: StreamBuilder<List<Washer>>(
                stream: firebaseService.getWashers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading washers...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            'Error loading washers',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please check your connection',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final washers = snapshot.data ?? [];

                  if (washers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No Washers Found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first washer using the form above',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Washers (${washers.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: washers.length,
                          itemBuilder: (context, index) {
                            final washer = washers[index];
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child:
                                      Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(
                                  washer.name,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      washer.phone ??
                                          'No phone number', // Handle null phone
                                      style: TextStyle(
                                        color: washer.phone == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      'Commission: ${washer.percentage}%',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Edit Button
                                    IconButton(
                                      icon:
                                          Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditWasherScreen(
                                                    washer: washer),
                                          ),
                                        );
                                      },
                                      tooltip: 'Edit Washer',
                                    ),
                                    // Delete Button
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteWasher(washer),
                                      tooltip: 'Delete Washer',
                                    ),
                                    // Status Indicator
                                    washer.isActive
                                        ? Icon(Icons.check_circle,
                                            color: Colors.green, size: 20)
                                        : Icon(Icons.cancel,
                                            color: Colors.red, size: 20),
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
