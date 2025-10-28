import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/washer.dart';
import '../services/firebase_service.dart';

class WasherReportsScreen extends StatefulWidget {
  @override
  _WasherReportsScreenState createState() => _WasherReportsScreenState();
}

class _WasherReportsScreenState extends State<WasherReportsScreen> {
  DateTimeRange? _selectedDateRange;
  String? _selectedWasherId;
  List<Washer> _allWashers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Set default to last 7 days
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
        _errorMessage = null; // Clear error when changing date range
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Washer Reports'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            height: 200,
            child: SingleChildScrollView(
              child: Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date Range Selector
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.calendar_today,
                            color: Colors.blue, size: 20),
                        title: Text(
                          'Date Range',
                          style: TextStyle(fontSize: 14),
                        ),
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
                            _allWashers = snapshot.data!;
                          }
                          if (snapshot.hasError) {}
                          return _buildWasherDropdown();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Error Message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Reports List
          Expanded(
            child: _buildReportsContent(firebaseService),
          ),
        ],
      ),
    );
  }

  Widget _buildWasherDropdown() {
    final uniqueWashers = _allWashers
        .fold<Map<String, Washer>>({}, (map, washer) {
          if (!map.containsKey(washer.id)) {
            map[washer.id] = washer;
          }
          return map;
        })
        .values
        .toList();

    if (_selectedWasherId != null &&
        !uniqueWashers.any((washer) => washer.id == _selectedWasherId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedWasherId = null;
        });
      });
    }

    return DropdownButtonFormField<String>(
      value: _selectedWasherId,
      decoration: InputDecoration(
        labelText: 'Filter by Washer',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      isExpanded: true,
      style: TextStyle(fontSize: 14),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All Washers', style: TextStyle(color: Colors.grey[600])),
        ),
        ...uniqueWashers.map((washer) {
          return DropdownMenuItem<String>(
            value: washer.id,
            child: Text(
              washer.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedWasherId = value;
          _errorMessage = null; // Clear error when changing washer
        });
      },
    );
  }

  Widget _buildReportsContent(FirebaseService firebaseService) {
    if (_selectedDateRange == null) {
      return Center(child: Text('Please select a date range'));
    }

    final startDate = _selectedDateRange!.start;
    final endDate = _selectedDateRange!.end;

    final adjustedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    return StreamBuilder<List<CarWash>>(
      stream: _selectedWasherId != null
          ? firebaseService.getCarWashesByWasherAndDateRange(
              _selectedWasherId!,
              startDate,
              adjustedEndDate,
            )
          : firebaseService.getCarWashesByDateRange(
              startDate,
              adjustedEndDate,
            ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {}
        if (snapshot.hasData) {}

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading reports...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();

          // Set the error message for display
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Error: $error';
              });
            }
          });

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading reports',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check the console for details',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final carWashes = snapshot.data ?? [];

        if (_selectedWasherId != null) {
          return _buildSingleWasherReport(carWashes, firebaseService);
        } else {
          return _buildAllWashersReport(carWashes, firebaseService);
        }
      },
    );
  }

  // ... rest of your methods (_buildSingleWasherReport, _buildAllWashersReport, etc.)
  // Keep the existing methods for building the report UI
  Widget _buildSingleWasherReport(
      List<CarWash> carWashes, FirebaseService firebaseService) {
    if (carWashes.isEmpty) {
      return _buildEmptyState();
    }

    return StreamBuilder<List<Washer>>(
      stream: firebaseService.getWashers(),
      builder: (context, washerSnapshot) {
        if (washerSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (washerSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Error loading washer details'),
              ],
            ),
          );
        }

        final washers = washerSnapshot.data ?? [];
        final washer = washers.firstWhere(
          (w) => w.id == _selectedWasherId,
          orElse: () => Washer(
            id: '',
            name: 'Unknown Washer',
            phone: '',
            percentage: 0,
            isActive: false,
            createdAt: DateTime.now(),
          ),
        );

        // Calculate totals
        final totalRevenue =
            carWashes.fold(0.0, (sum, wash) => sum + wash.amount);
        final washerCommission = totalRevenue * (washer.percentage / 100);
        final ownerRevenue = totalRevenue - washerCommission;

        return Column(
          children: [
            // Summary Card
            Card(
              margin: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      child: Text(
                        washer.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${carWashes.length} vehicles washed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      constraints: BoxConstraints(
                        minHeight: 60,
                        maxHeight: 80,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total',
                              '\$${totalRevenue.toStringAsFixed(2)}',
                              Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              'Commission',
                              '\$${washerCommission.toStringAsFixed(2)}',
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              'Owner',
                              '\$${ownerRevenue.toStringAsFixed(2)}',
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: carWashes.length,
                itemBuilder: (context, index) {
                  final carWash = carWashes[index];
                  return _buildCarWashItem(carWash);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAllWashersReport(
      List<CarWash> carWashes, FirebaseService firebaseService) {
    if (carWashes.isEmpty) {
      return _buildEmptyState();
    }

    return StreamBuilder<List<Washer>>(
      stream: firebaseService.getWashers(),
      builder: (context, washerSnapshot) {
        if (washerSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final washers = washerSnapshot.data ?? [];

        // Group car washes by washer
        final Map<String, List<CarWash>> washerGroups = {};
        for (final carWash in carWashes) {
          washerGroups.putIfAbsent(carWash.washerId, () => []);
          washerGroups[carWash.washerId]!.add(carWash);
        }

        // Calculate totals for each washer
        final List<WasherReport> washerReports = [];
        washerGroups.forEach((washerId, washes) {
          final washer = washers.firstWhere(
            (w) => w.id == washerId,
            orElse: () => Washer(
              id: washerId,
              name: 'Unknown Washer',
              phone: '',
              percentage: 0,
              isActive: false,
              createdAt: DateTime.now(),
            ),
          );

          final totalRevenue =
              washes.fold(0.0, (sum, wash) => sum + wash.amount);
          final commission = totalRevenue * (washer.percentage / 100);

          washerReports.add(WasherReport(
            washer: washer,
            carWashes: washes,
            totalRevenue: totalRevenue,
            commission: commission,
          ));
        });

        // Sort by total revenue (descending)
        washerReports.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

        return ListView.builder(
          itemCount: washerReports.length,
          itemBuilder: (context, index) {
            final report = washerReports[index];
            return _buildWasherReportCard(report);
          },
        );
      },
    );
  }

  Widget _buildWasherReportCard(WasherReport report) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 12),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blue,
          child: Text(
            report.washer.name.isNotEmpty
                ? report.washer.name[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          report.washer.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${report.carWashes.length} vehicles • \$${report.totalRevenue.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${report.commission.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Commission',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),
        children: [
          Divider(height: 1),
          ...report.carWashes
              .map((carWash) => _buildCarWashItem(carWash))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildCarWashItem(CarWash carWash) {
    return Container(
      height: 70,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          _getVehicleIcon(carWash.vehicleType),
          color: Colors.blue,
          size: 20,
        ),
        title: Text(
          carWash.vehicleType,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Container(
          height: 40, // Fixed height for subtitle area
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (carWash.plateNumber != null &&
                    carWash.plateNumber!.isNotEmpty)
                  Text(
                    'Plate: ${carWash.plateNumber}',
                    style: TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  DateFormat('MMM dd, HH:mm').format(carWash.date),
                  style: TextStyle(fontSize: 11),
                ),
                if (carWash.notes != null && carWash.notes!.isNotEmpty)
                  Text(
                    'Notes: ${carWash.notes!}',
                    style: TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ),
        trailing: Text(
          '\$${carWash.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_car_wash, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No car washes found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Try selecting a different date range or washer',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'suv':
        return Icons.airport_shuttle;
      case 'truck':
        return Icons.local_shipping;
      case 'motorcycle':
        return Icons.motorcycle;
      default:
        return Icons.directions_car;
    }
  }
}

class WasherReport {
  final Washer washer;
  final List<CarWash> carWashes;
  final double totalRevenue;
  final double commission;

  WasherReport({
    required this.washer,
    required this.carWashes,
    required this.totalRevenue,
    required this.commission,
  });
}
