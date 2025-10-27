import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class WasherManagement extends StatefulWidget {
  const WasherManagement({super.key});

  @override
  _WasherManagementState createState() => _WasherManagementState();
}

class _WasherManagementState extends State<WasherManagement> {
  // Controllers and state for the form
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  double _percentage = 50.0;
  bool _isActive = true;

  // New state to manage which washer is currently being edited
  Washer? _editingWasher;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // General function to save (Add or Update) a washer
  Future<void> _saveWasher() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and phone.')),
      );
      return;
    }

    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);

    final washer = Washer(
      // Use existing ID for update, or generate a new one for add
      id: _editingWasher?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      phone: _phoneController.text,
      percentage: _percentage,
      isActive: _isActive, // Use the state from the form
    );

    if (_editingWasher == null) {
      // ADD NEW WASHER
      await firebaseService.addWasher(washer);
    } else {
      // UPDATE EXISTING WASHER
      await firebaseService.updateWasher(washer);
    }

    // Dismiss dialog and show success message
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_editingWasher == null
              ? 'Washer added successfully!'
              : 'Washer updated successfully!')),
    );
  }

  // Function to handle deleting a washer
  Future<void> _deleteWasher(Washer washer) async {
    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);

    // Simple confirmation dialog before deleting
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${washer.name}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await firebaseService.deleteWasher(washer.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${washer.name} deleted.')),
      );
    }
  }

  // Function to show the Add/Edit form dialog
  void _showWasherForm([Washer? washer]) {
    setState(() {
      _editingWasher = washer;
      if (washer != null) {
        // Populate fields for editing
        _nameController.text = washer.name;
        _phoneController.text = washer.phone;
        _percentage = washer.percentage;
        _isActive = washer.isActive;
      } else {
        // Clear fields for adding new
        _nameController.clear();
        _phoneController.clear();
        _percentage = 50.0;
        _isActive = true;
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text(washer == null ? 'Add New Washer' : 'Edit Washer'),
              content: SingleChildScrollView(
                child: Column(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Commission Percentage: ${_percentage.toStringAsFixed(1)}%'),
                        Slider(
                          value: _percentage,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (value) {
                            setStateSB(() {
                              _percentage = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Is Active'),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setStateSB(() {
                              _isActive = value;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _saveWasher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(washer == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Only owners can manage washers.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Washer Management'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // The ADD CARD has been replaced by the FloatingActionButton
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<Washer>>(
                stream: firebaseService.getWashers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                          'No washers found. Tap the plus button to add one!'),
                    );
                  }

                  final washers = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount: washers.length,
                    itemBuilder: (context, index) {
                      final washer = washers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.person,
                              color: washer.isActive
                                  ? Colors.orange
                                  : Colors.grey),
                          title: Text(washer.name,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${washer.phone} • ${washer.percentage.toStringAsFixed(1)}% Commission'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // EDIT ACTION
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showWasherForm(washer),
                              ),
                              // DELETE ACTION
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteWasher(washer),
                              ),
                            ],
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
      // Floating Action Button to add a new washer
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWasherForm(null),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
