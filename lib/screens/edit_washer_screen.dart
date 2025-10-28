import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/washer.dart';
import '../services/firebase_service.dart';

class EditWasherScreen extends StatefulWidget {
  final Washer washer;

  const EditWasherScreen({Key? key, required this.washer}) : super(key: key);

  @override
  _EditWasherScreenState createState() => _EditWasherScreenState();
}

class _EditWasherScreenState extends State<EditWasherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  double _percentage = 50.0;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.washer.name;
    _phoneController.text = widget.washer.phone ?? ''; // Handle null phone
    _percentage = widget.washer.percentage;
    _isActive = widget.washer.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateWasher() async {
    if (_formKey.currentState!.validate()) {
      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);

        final updatedWasher = Washer(
          id: widget.washer.id,
          name: _nameController.text,
          phone: _phoneController.text,
          percentage: _percentage,
          isActive: _isActive,
          createdAt: widget.washer.createdAt,
        );

        await firebaseService.updateWasher(updatedWasher);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washer updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context); // Go back to previous screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating washer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteWasher() async {
    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Washer'),
          content: Text(
            'Are you sure you want to delete ${widget.washer.name}? This action cannot be undone.',
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
        await firebaseService.deleteWasher(widget.washer.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washer deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context); // Go back to previous screen
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Washer'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _updateWasher,
            tooltip: 'Save Changes',
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteWasher,
            tooltip: 'Delete Washer',
            color: Colors.red,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Edit Washer Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter washer name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Phone Field
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 16),

                      // Commission Percentage
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

                      // Active Status Toggle
                      Row(
                        children: [
                          Text(
                            'Active Status: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Switch(
                            value: _isActive,
                            onChanged: (value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                          Text(_isActive ? 'Active' : 'Inactive'),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        onPressed: _updateWasher,
                        child: Text(
                          'Update Washer',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Delete Button
                      OutlinedButton(
                        onPressed: _deleteWasher,
                        child: Text(
                          'Delete Washer',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
