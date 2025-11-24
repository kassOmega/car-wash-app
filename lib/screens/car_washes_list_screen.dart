// screens/car_washes_list_screen.dart - UPDATED
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/washer.dart';
import '../services/firebase_service.dart';

class CarWashesListScreen extends StatefulWidget {
  const CarWashesListScreen({super.key});

  @override
  _CarWashesListScreenState createState() => _CarWashesListScreenState();
}

class _CarWashesListScreenState extends State<CarWashesListScreen> {
  DateTimeRange? _selectedDateRange;
  String? _selectedWasherId;
  String _plateNumberFilter = '';
  List<Washer> _washers = [];
  final Map<String, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: 7));
    _selectedDateRange = DateTimeRange(start: startDate, end: endDate);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 7)),
        end: DateTime.now(),
      );
      _selectedWasherId = null;
      _plateNumberFilter = '';
      _expandedItems.clear();
    });
  }

  void _toggleExpanded(String carWashId) {
    setState(() {
      _expandedItems[carWashId] = !(_expandedItems[carWashId] ?? false);
    });
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'In Progress';
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Car Washes List'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: _clearFilters,
            tooltip: 'Clear Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Card
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Date Range
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today, size: 20),
                    title: Text('Date Range', style: TextStyle(fontSize: 14)),
                    subtitle: _selectedDateRange == null
                        ? Text('Select date range',
                            style: TextStyle(fontSize: 12))
                        : Text(
                            '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                            style: TextStyle(fontSize: 12),
                          ),
                    trailing: Icon(Icons.arrow_drop_down, size: 20),
                    onTap: () => _selectDateRange(context),
                  ),

                  Divider(height: 20),

                  // Washer Filter
                  StreamBuilder<List<Washer>>(
                    stream: firebaseService.getWashers(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _washers = snapshot.data!;
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedWasherId,
                        decoration: InputDecoration(
                          labelText: 'Filter by Washer',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Washers',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ..._washers.map((washer) {
                            return DropdownMenuItem(
                              value: washer.id,
                              child: Text(washer.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedWasherId = value;
                          });
                        },
                      );
                    },
                  ),

                  SizedBox(height: 12),

                  // Plate Number Filter
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Plate Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _plateNumberFilter = value.toUpperCase();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Car Washes List
          Expanded(
            child: _buildCarWashesList(firebaseService),
          ),
        ],
      ),
    );
  }

  Widget _buildCarWashesList(FirebaseService firebaseService) {
    if (_selectedDateRange == null) {
      return Center(child: Text('Please select date range'));
    }

    final startDate = _selectedDateRange!.start;
    final endDate = DateTime(
      _selectedDateRange!.end.year,
      _selectedDateRange!.end.month,
      _selectedDateRange!.end.day,
      23,
      59,
      59,
    );

    return StreamBuilder<List<CarWash>>(
      stream: _selectedWasherId != null
          ? firebaseService.getCarWashesByWasherAndDateRange(
              _selectedWasherId!, startDate, endDate)
          : firebaseService.getCarWashesByDateRange(startDate, endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final carWashes = snapshot.data ?? [];

        // Apply plate number filter
        final filteredCarWashes = _plateNumberFilter.isEmpty
            ? carWashes
            : carWashes
                .where((wash) =>
                    wash.plateNumber
                        ?.toUpperCase()
                        .contains(_plateNumberFilter) ??
                    false)
                .toList();

        if (filteredCarWashes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_car_wash, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No car washes found'),
                SizedBox(height: 8),
                Text('Try adjusting your filters'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredCarWashes.length,
          itemBuilder: (context, index) {
            final carWash = filteredCarWashes[index];
            final isExpanded = _expandedItems[carWash.id] ?? false;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: StreamBuilder<List<Washer>>(
                stream: firebaseService.getWashers(),
                builder: (context, washerSnapshot) {
                  final washers = washerSnapshot.data ?? [];
                  final responsibleWasher = washers.firstWhere(
                    (w) => w.id == carWash.washerId,
                    orElse: () => Washer(
                      id: '',
                      name: 'Unknown Washer',
                      phone: '',
                      percentage: 0,
                      isActive: false,
                      createdAt: DateTime.now(),
                    ),
                  );

                  final participantNames =
                      carWash.participantWasherIds.map((id) {
                    final washer = washers.firstWhere(
                      (w) => w.id == id,
                      orElse: () => Washer(
                        id: id,
                        name: 'Unknown',
                        phone: '',
                        percentage: 0,
                        isActive: false,
                        createdAt: DateTime.now(),
                      ),
                    );
                    return washer.name;
                  }).toList();

                  return ExpansionTile(
                    key: Key(carWash.id),
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (expanded) =>
                        _toggleExpanded(carWash.id),
                    leading: Icon(
                      carWash.isCompleted ? Icons.check_circle : Icons.schedule,
                      color: carWash.isCompleted ? Colors.green : Colors.orange,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                carWash.plateNumber ?? 'No Plate',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                responsibleWasher.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ETB ${carWash.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              carWash.vehicleType,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text(DateFormat('MMM dd').format(carWash.date)),
                        SizedBox(width: 8),
                        Icon(Icons.access_time, size: 12),
                        SizedBox(width: 4),
                        Text(DateFormat('HH:mm').format(carWash.date)),
                        if (carWash.isCompleted &&
                            carWash.completedAt != null) ...[
                          SizedBox(width: 8),
                          Text('•'),
                          SizedBox(width: 8),
                          Icon(Icons.timer, size: 12),
                          SizedBox(width: 4),
                          Text(_formatDuration(carWash.duration)),
                        ],
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vehicle Details
                            _buildDetailRow(
                                'Vehicle Type', carWash.vehicleType),
                            _buildDetailRow('Amount',
                                'ETB ${carWash.amount.toStringAsFixed(0)}'),

                            // Time Details
                            _buildDetailRow(
                                'Started',
                                DateFormat('MMM dd, yyyy - HH:mm')
                                    .format(carWash.date)),
                            if (carWash.isCompleted &&
                                carWash.completedAt != null)
                              _buildDetailRow(
                                  'Completed',
                                  DateFormat('MMM dd, yyyy - HH:mm')
                                      .format(carWash.completedAt!)),
                            if (carWash.duration != null)
                              _buildDetailRow('Duration',
                                  _formatDuration(carWash.duration!)),

                            // Washer Details
                            _buildDetailRow(
                                'Responsible Washer', responsibleWasher.name),
                            if (participantNames.isNotEmpty)
                              _buildDetailRow('Helper Washers',
                                  participantNames.join(', ')),

                            // Additional Info
                            if (carWash.notes != null &&
                                carWash.notes!.isNotEmpty)
                              _buildDetailRow('Notes', carWash.notes!),

                            if (carWash.recordedBy != null)
                              _buildDetailRow(
                                  'Recorded By', carWash.recordedBy!),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
