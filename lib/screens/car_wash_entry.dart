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
  const CarWashEntry({super.key});

  @override
  _CarWashEntryState createState() => _CarWashEntryState();
}

class _CarWashEntryState extends State<CarWashEntry> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedWasherId; // Responsible washer
  List<String> _selectedParticipantWasherIds = []; // Participant washers
  String _vehicleType = 'Car';
  List<Price> _prices = [];

  List<Customer> _customers = [];
  List<CarWash> _todayCarWashes = [];

  bool _isLoadingTodayWashes = false;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _isUpdating = false;
  String? _updatingCarWashId;
  bool _isMarkingDone = false;
  String? _markingDoneCarWashId;

  @override
  void initState() {
    super.initState();
    _updateAmountForVehicleType(_vehicleType);
    _loadTodayCarWashes();
  }

  Future<void> _loadTodayCarWashes() async {
    setState(() {
      _isLoadingTodayWashes = true;
    });

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final carWashes = await firebaseService
          .getCarWashesByDateRange(todayStart, todayEnd)
          .first;

      setState(() {
        _todayCarWashes = carWashes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading today\'s washes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingTodayWashes = false;
      });
    }
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
      setState(() {
        _isSubmitting = true;
      });

      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final carWash = CarWash(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: _selectedCustomerId,
        washerId: _selectedWasherId!, // Responsible washer
        participantWasherIds: _selectedParticipantWasherIds, // Participants
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

        // Clear form
        _amountController.clear();
        _plateNumberController.clear();
        _notesController.clear();
        setState(() {
          _selectedCustomerId = null;
          _selectedWasherId = null;
          _selectedParticipantWasherIds.clear();
        });

        _updateAmountForVehicleType(_vehicleType);
        await _loadTodayCarWashes();

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
      } finally {
        setState(() {
          _isSubmitting = false;
        });
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

  Future<void> _updateCarWash(CarWash carWash) async {
    if (_formKey.currentState!.validate() && _selectedWasherId != null) {
      setState(() {
        _isUpdating = true;
      });

      try {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);

        final updatedCarWash = CarWash(
          id: carWash.id,
          customerId: _selectedCustomerId,
          washerId: _selectedWasherId!,
          participantWasherIds: _selectedParticipantWasherIds,
          vehicleType: _vehicleType,
          amount: double.tryParse(_amountController.text) ?? 0.0,
          date: carWash.date, // Keep original date
          notes:
              _notesController.text.isNotEmpty ? _notesController.text : null,
          recordedBy: carWash.recordedBy, // Keep original recorder
          plateNumber: _plateNumberController.text.isNotEmpty
              ? _plateNumberController.text
              : null,
        );

        await firebaseService.updateCarWash(updatedCarWash);

        // Clear form and reset update mode
        _clearForm();

        await _loadTodayCarWashes();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Car wash updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating car wash: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isUpdating = false;
        });
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

  Future<void> _markAsDone(CarWash carWash) async {
    setState(() {
      _isMarkingDone = true;
      _markingDoneCarWashId = carWash.id;
    });

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      final updatedCarWash = carWash.copyWith(
        status: 'completed',
        completedAt: DateTime.now(),
      );

      await firebaseService.updateCarWash(updatedCarWash);

      await _loadTodayCarWashes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Car wash marked as completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking as done: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isMarkingDone = false;
        _markingDoneCarWashId = null;
      });
    }
  }

  void _loadCarWashIntoForm(CarWash carWash) {
    setState(() {
      _updatingCarWashId = carWash.id;
      _selectedCustomerId = carWash.customerId;
      _selectedWasherId = carWash.washerId;
      _selectedParticipantWasherIds = List.from(carWash.participantWasherIds);
      _vehicleType = carWash.vehicleType;
      _amountController.text = carWash.amount.toStringAsFixed(0);
      _plateNumberController.text = carWash.plateNumber ?? '';
      _notesController.text = carWash.notes ?? '';
    });

    // Scroll to top to show the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(_formKey.currentContext!);
    });
  }

  Future<void> _deleteCarWash(String carWashId) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      final bool? confirm = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete Car Wash'),
            content: Text(
                'Are you sure you want to delete this car wash record? This action cannot be undone.'),
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

      if (confirm == true) {
        await firebaseService.deleteCarWash(carWashId);
        await _loadTodayCarWashes();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Car wash record deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting car wash: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
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
      _selectedParticipantWasherIds.clear();
      _vehicleType = 'Car';
      _updatingCarWashId = null;
    });
    _updateAmountForVehicleType(_vehicleType);
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getWasherName(String washerId, List<Washer> washers) {
    try {
      if (washers.isEmpty) return 'Loading...';
      final washer = washers.firstWhere((w) => w.id == washerId);
      return washer.name;
    } catch (e) {
      return 'Unknown Washer';
    }
  }

  String _getWasherNames(List<String> washerIds, List<Washer> washers) {
    try {
      if (washers.isEmpty) return 'Loading...';
      final washerNames = washerIds.map((washerId) {
        final washer = washers.firstWhere((w) => w.id == washerId);
        return washer.name;
      }).toList();
      return washerNames.join(', ');
    } catch (e) {
      return 'Unknown Washers';
    }
  }

  // Helper method to filter active washers
  List<Washer> _getActiveWashers(List<Washer> allWashers) {
    return allWashers.where((washer) => washer.isActive).toList();
  }

  Widget _buildWasherSelection(List<Washer> allWashers) {
    final activeWashers = _getActiveWashers(allWashers);

    if (activeWashers.isEmpty) {
      return Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No active washers available. Please add or activate washers first.',
            style: TextStyle(color: Colors.orange[800]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedWasherId,
          decoration: InputDecoration(
            labelText: 'Responsible Washer *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_car_wash),
            errorText: _selectedWasherId == null
                ? 'Please select a responsible washer'
                : null,
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              enabled: false,
              child: Text('Select responsible washer',
                  style: TextStyle(color: Colors.grey)),
            ),
            ...activeWashers.map((washer) {
              return DropdownMenuItem<String>(
                value: washer.id,
                child: Text('${washer.name} (${washer.percentage}%)'),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedWasherId = value;
              // Remove the selected responsible washer from participants if they were there
              if (value != null) {
                _selectedParticipantWasherIds.remove(value);
              }
            });
          },
          validator: (value) =>
              value == null ? 'Please select a responsible washer' : null,
        ),
        SizedBox(height: 8),
        Text(
          'The responsible washer receives the commission',
          style: TextStyle(
              fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildParticipantWashersSelection(List<Washer> allWashers) {
    final activeWashers = _getActiveWashers(allWashers);

    // Filter out the responsible washer from participant options
    final availableWashers = activeWashers
        .where((washer) => washer.id != _selectedWasherId)
        .toList();

    if (availableWashers.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Participant Washers (Helpers) - Optional',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Other washers who helped with this car wash',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 8),

        // Multi-select dropdown for participant washers
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ExpansionTile(
            title: Text(
              _selectedParticipantWasherIds.isEmpty
                  ? 'Select participant washers'
                  : '${_selectedParticipantWasherIds.length} washers selected',
              style: TextStyle(
                color: _selectedParticipantWasherIds.isEmpty
                    ? Colors.grey
                    : Colors.black,
              ),
            ),
            children: [
              Container(
                height: 200, // Fixed height for scrollable content
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableWashers.length,
                  itemBuilder: (context, index) {
                    final washer = availableWashers[index];
                    final isSelected =
                        _selectedParticipantWasherIds.contains(washer.id);

                    return CheckboxListTile(
                      title: Text(washer.name),
                      subtitle: Text('${washer.percentage}% commission rate'),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedParticipantWasherIds.add(washer.id);
                          } else {
                            _selectedParticipantWasherIds.remove(washer.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Show selected participants summary
        if (_selectedParticipantWasherIds.isNotEmpty) ...[
          SizedBox(height: 12),
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Participants:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedParticipantWasherIds.map((id) {
                      final washer = allWashers.firstWhere((w) => w.id == id);
                      return Chip(
                        label: Text(washer.name),
                        backgroundColor: Colors.blue[100],
                        deleteIcon: Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedParticipantWasherIds.remove(id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTodayWashesList(List<Washer> allWashers) {
    if (_isLoadingTodayWashes) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading today\'s washes...'),
            ],
          ),
        ),
      );
    }

    if (_todayCarWashes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.local_car_wash, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No car washes recorded today',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final totalAmount =
        _todayCarWashes.fold(0.0, (sum, wash) => sum + wash.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Car Washes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Chip(
              backgroundColor: Colors.blue[50],
              label: Text(
                'ETB ${totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Total: ${_todayCarWashes.length} washes',
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 16),
        ..._todayCarWashes.map((carWash) {
          final isUpdatingThisCarWash =
              _isUpdating && _updatingCarWashId == carWash.id;
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);

          final isMarkingThisDone =
              _isMarkingDone && _markingDoneCarWashId == carWash.id;
          final isCompleted = carWash.isCompleted;

          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.local_car_wash, color: Colors.blue[800]),
              ),
              title: Text(
                '${carWash.vehicleType} - ETB ${carWash.amount.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plate: ${carWash.plateNumber ?? "No Plate"}'),
                  Text(
                      'Washer: ${_getWasherName(carWash.washerId, allWashers)}'),
                  if (carWash.participantWasherIds.isNotEmpty)
                    Text(
                        'Helpers: ${_getWasherNames(carWash.participantWasherIds, allWashers)}'),
                  Text('Started: ${_formatTime(carWash.date)}'),
                  if (carWash.isCompleted && carWash.completedAt != null)
                    Text('Completed: ${_formatTime(carWash.completedAt!)}'),
                  if (carWash.duration != null)
                    Text('Duration: ${_formatDuration(carWash.duration!)}'),
                  if (carWash.notes != null) Text('Notes: ${carWash.notes}'),
                ],
              ),
              trailing: isMarkingThisDone
                  ? CircularProgressIndicator()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isCompleted) ...[
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => _markAsDone(carWash),
                            tooltip: 'Mark as Done',
                          ),
                          SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _loadCarWashIntoForm(carWash),
                        ),
                        if (authProvider.isOwner)
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteCarWash(carWash.id),
                          ),
                      ],
                    ),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _updatingCarWashId != null ? 'Update Car Wash' : 'Record Car Wash'),
        backgroundColor:
            _updatingCarWashId != null ? Colors.orange : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_updatingCarWashId != null)
            IconButton(
              icon: Icon(Icons.cancel),
              onPressed: _clearForm,
              tooltip: 'Cancel Update',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTodayCarWashes,
            tooltip: 'Refresh Today\'s List',
          ),
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
      body: SingleChildScrollView(
        // MADE THE WHOLE PAGE SCROLLABLE
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<Washer>>(
            stream: firebaseService.getWashers(),
            builder: (context, washersSnapshot) {
              if (washersSnapshot.connectionState == ConnectionState.waiting) {
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

              if (washersSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error loading washers'),
                      SizedBox(height: 8),
                      Text(
                        washersSnapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final allWashers = washersSnapshot.data ?? [];

              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _updatingCarWashId != null
                                  ? 'Update Car Wash'
                                  : 'Record New Car Wash',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Customer Selection
                            if (authProvider.isOwner ||
                                authProvider.isCashier) ...[
                              StreamBuilder<List<Customer>>(
                                stream: firebaseService.getCustomers(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return DropdownButtonFormField<String>(
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
                                      }),
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

                            // Responsible Washer Selection
                            _buildWasherSelection(allWashers),

                            // Participant Washers Selection
                            _buildParticipantWashersSelection(allWashers),

                            SizedBox(height: 16),

                            // Vehicle Type
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
                                      child: Text(price.vehicleType),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _vehicleType = value!;
                                    });
                                    _updateAmountForVehicleType(value!);
                                  },
                                );
                              },
                            ),
                            SizedBox(height: 16),

                            // Plate Number
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

                            // Amount
                            TextFormField(
                              controller: _amountController,
                              decoration: InputDecoration(
                                labelText: 'Amount *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.refresh),
                                  onPressed: () =>
                                      _updateAmountForVehicleType(_vehicleType),
                                  tooltip: 'Reset to default price',
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Please enter amount';
                                final amount = double.tryParse(value);
                                if (amount == null)
                                  return 'Please enter valid amount';
                                if (amount <= 0)
                                  return 'Amount must be greater than 0';
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

                            // Submit/Update Button
                            ElevatedButton(
                              onPressed: (_isSubmitting || _isUpdating)
                                  ? null
                                  : () {
                                      if (_updatingCarWashId != null) {
                                        final carWashToUpdate = _todayCarWashes
                                            .firstWhere((carWash) =>
                                                carWash.id ==
                                                _updatingCarWashId);
                                        _updateCarWash(carWashToUpdate);
                                      } else {
                                        _submitCarWash();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _updatingCarWashId != null
                                    ? Colors.orange
                                    : Colors.blue,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: (_isSubmitting || _isUpdating)
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(_isUpdating
                                            ? 'Updating...'
                                            : 'Recording...'),
                                      ],
                                    )
                                  : Text(_updatingCarWashId != null
                                      ? 'Update Car Wash'
                                      : 'Record Car Wash'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Today's Washes List
                  _buildTodayWashesList(allWashers),
                ],
              );
            },
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
