import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/washer.dart';
import '../services/firebase_service.dart';
import 'edit_washer_screen.dart';

class WasherManagement extends StatefulWidget {
  const WasherManagement({super.key});

  @override
  _WasherManagementState createState() => _WasherManagementState();
}

class _WasherManagementState extends State<WasherManagement> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  double _percentage = 50.0;

  // Loading states
  bool _isAddingWasher = false;
  bool _isDeletingWasher = false;
  String? _deletingWasherId;
  String? _errorMessage;

  Future<void> _addWasher() async {
    if (_nameController.text.isNotEmpty) {
      setState(() {
        _isAddingWasher = true;
        _errorMessage = null;
      });

      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      // Generate a proper ID
      final washerId = DateTime.now().millisecondsSinceEpoch.toString();

      final washer = Washer(
        id: washerId,
        name: _nameController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        percentage: _percentage,
        createdAt: DateTime.now(),
      );

      try {
        await firebaseService.addWasher(washer);

        _nameController.clear();
        _phoneController.clear();
        setState(() {
          _percentage = 50.0;
          _isAddingWasher = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washer added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        setState(() {
          _isAddingWasher = false;
          _errorMessage = 'Error adding washer: $e';
        });

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
      setState(() {
        _isDeletingWasher = true;
        _deletingWasherId = washer.id;
        _errorMessage = null;
      });

      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);

        // Double-check ID before deletion
        if (washer.id.isNotEmpty) {
          await firebaseService.deleteWasher(washer.id);

          setState(() {
            _isDeletingWasher = false;
            _deletingWasherId = null;
          });

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
        setState(() {
          _isDeletingWasher = false;
          _deletingWasherId = null;
          _errorMessage = 'Error deleting washer: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting washer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Washer Management'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // The stream will automatically refresh
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refreshing washers...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Error Display
            if (_errorMessage != null) ...[
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20),
                        onPressed: _clearError,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
            ],

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
                          onChanged: _isAddingWasher
                              ? null
                              : (value) {
                                  setState(() {
                                    _percentage = value;
                                  });
                                },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isAddingWasher ? null : _addWasher,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: _isAddingWasher
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Adding Washer...'),
                              ],
                            )
                          : Text('Add Washer'),
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
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final washers = snapshot.data ?? [];

                  if (washers.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildWashersList(washers);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading washers...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading washers',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // The stream will automatically retry
              setState(() {});
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
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

  Widget _buildWashersList(List<Washer> washers) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Washers (${washers.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isDeletingWasher)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Deleting...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: washers.length,
            itemBuilder: (context, index) {
              final washer = washers[index];
              final isDeletingThisWasher =
                  _isDeletingWasher && _deletingWasherId == washer.id;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    washer.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        washer.phone ?? 'No phone number',
                        style: TextStyle(
                          color:
                              washer.phone == null ? Colors.grey : Colors.black,
                        ),
                      ),
                      Text(
                        'Commission: ${washer.percentage}%',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                  trailing: isDeletingThisWasher
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit Button
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: _isDeletingWasher
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditWasherScreen(washer: washer),
                                        ),
                                      );
                                    },
                              tooltip: 'Edit Washer',
                            ),
                            // Delete Button
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: _isDeletingWasher
                                  ? null
                                  : () => _deleteWasher(washer),
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
