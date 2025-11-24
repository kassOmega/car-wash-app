import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class WasherReportsScreen extends StatefulWidget {
  const WasherReportsScreen({super.key});

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
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Washer Reports'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          // Use LayoutBuilder for responsive constraints
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              child: Column(
                children: [
                  // Filters Section
                  Card(
                    margin: EdgeInsets.all(12),
                    color: Colors.blue[50],
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
                              if (snapshot.hasError) {
                                // Handle error silently
                              }
                              return _buildWasherDropdown(authProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                    child: Container(
                      width: constraints.maxWidth,
                      child:
                          _buildReportsContent(firebaseService, authProvider),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWasherDropdown(AuthProvider authProvider) {
    final uniqueWashers = _allWashers
        .fold<Map<String, Washer>>({}, (map, washer) {
          if (!map.containsKey(washer.id)) {
            map[washer.id] = washer;
          }
          return map;
        })
        .values
        .toList();

    // If current user is a washer, automatically select themselves
    if (authProvider.isWasher && _selectedWasherId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedWasherId = authProvider.user?.uid;
        });
      });
    }

    if (_selectedWasherId != null &&
        !uniqueWashers.any((washer) => washer.id == _selectedWasherId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedWasherId = null;
        });
      });
    }

    // If user is washer, don't show dropdown - automatically show their reports
    if (authProvider.isWasher) {
      final currentWasher = uniqueWashers.firstWhere(
        (washer) => washer.id == authProvider.user?.uid,
        orElse: () => Washer(
          id: '',
          name: 'Unknown Washer',
          phone: '',
          percentage: 0,
          isActive: false,
          createdAt: DateTime.now(),
        ),
      );

      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.person, color: Colors.blue, size: 20),
        title: Text(
          'Washer',
          style: TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          currentWasher.name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedWasherId,
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
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedWasherId = value;
          _errorMessage = null;
        });
      },
    );
  }

  Widget _buildReportsContent(
      FirebaseService firebaseService, AuthProvider authProvider) {
    if (_selectedDateRange == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text('Please select a date range')),
      );
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading reports...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Error: $error';
              });
            }
          });

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
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
            ),
          );
        }

        final carWashes = snapshot.data ?? [];

        if (_selectedWasherId != null) {
          return _buildSingleWasherReport(
              carWashes, firebaseService, authProvider);
        } else {
          return _buildAllWashersReport(
              carWashes, firebaseService, authProvider);
        }
      },
    );
  }

  Widget _buildSingleWasherReport(List<CarWash> carWashes,
      FirebaseService firebaseService, AuthProvider authProvider) {
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
        double totalRevenue = 0.0;
        double washerCommission = 0.0;
        int totalVehicles = 0;

        for (final wash in carWashes) {
          totalRevenue += wash.amount;
          totalVehicles += 1;

          // Get washer's percentage to calculate commission
          final washerPercentage = washer.percentage;
          washerCommission += wash.amount * (washerPercentage / 100);
        }

        final ownerRevenue = totalRevenue - washerCommission;
        final averageCommission =
            totalVehicles > 0 ? washerCommission / totalVehicles : 0;

        return ListView(
          // FIX: Use ListView instead of SingleChildScrollView
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
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
                    SizedBox(
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
                      '$totalVehicles vehicles washed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Revenue',
                            'ETB ${totalRevenue.toStringAsFixed(2)}',
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'My Commission',
                            'ETB ${washerCommission.toStringAsFixed(2)}',
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (authProvider.isOwner || authProvider.isCashier)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Owner Share',
                              'ETB ${ownerRevenue.toStringAsFixed(2)}',
                              Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              'Avg/Vehicle',
                              'ETB ${averageCommission.toStringAsFixed(2)}',
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Car Washes List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Car Wash Details:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...carWashes.map((carWash) {
                    return _buildCarWashItem(carWash, washers);
                  }).toList(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAllWashersReport(List<CarWash> carWashes,
      FirebaseService firebaseService, AuthProvider authProvider) {
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
        final Map<String, WasherReport> washerReports = {};

        for (final carWash in carWashes) {
          // Only count the responsible washer for commission
          final responsibleWasherId = carWash.washerId;
          final washer = washers.firstWhere(
            (w) => w.id == responsibleWasherId,
            orElse: () => Washer(
              id: responsibleWasherId,
              name: 'Unknown Washer',
              phone: '',
              percentage: 0,
              isActive: false,
              createdAt: DateTime.now(),
            ),
          );

          if (!washerReports.containsKey(washer.id)) {
            washerReports[washer.id] = WasherReport(
              washer: washer,
              carWashes: [],
              totalRevenue: 0.0,
              commission: 0.0,
              vehicleCount: 0,
            );
          }

          final report = washerReports[washer.id]!;
          report.carWashes.add(carWash);
          report.totalRevenue += carWash.amount;
          report.commission += carWash.amount * (washer.percentage / 100);
          report.vehicleCount += 1;
        }

        final washerReportList = washerReports.values.toList();

        // Sort by commission (descending)
        washerReportList.sort((a, b) => b.commission.compareTo(a.commission));

        return ListView.builder(
          // FIX: Use ListView.builder instead of SingleChildScrollView
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: washerReportList.length,
          itemBuilder: (context, index) {
            return _buildWasherReportCard(
                washerReportList[index], authProvider, washers);
          },
        );
      },
    );
  }

  Widget _buildWasherReportCard(
      WasherReport report, AuthProvider authProvider, List<Washer> washers) {
    final averageCommission =
        report.vehicleCount > 0 ? report.commission / report.vehicleCount : 0;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 12),
        leading: Container(
          width: 32,
          child: CircleAvatar(
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
        ),
        title: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
          child: Text(
            report.washer.name,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
          child: Text(
            '${report.vehicleCount} vehicles • ETB ${report.totalRevenue.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Container(
          width: 75,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ETB ${report.commission.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Commission',
                style: TextStyle(fontSize: 9, color: Colors.grey),
                maxLines: 1,
              ),
              if (!authProvider.isWasher)
                Text(
                  'Avg: ETB ${averageCommission.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 8, color: Colors.green),
                  maxLines: 1,
                ),
            ],
          ),
        ),
        children: [
          Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...report.carWashes.map((carWash) {
                      return _buildCarWashItem(carWash, washers);
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarWashItem(CarWash carWash, List<Washer> washers) {
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

    final participantNames = carWash.participantWasherIds.map((id) {
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

    final commission = carWash.amount * (responsibleWasher.percentage / 100);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
        leading: Container(
          width: 32,
          child: Icon(
            _getVehicleIcon(carWash.vehicleType),
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          carWash.vehicleType,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Washer: ${responsibleWasher.name}',
              style: TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (participantNames.isNotEmpty)
              Text(
                'Team: ${participantNames.join(", ")}',
                style: TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (carWash.plateNumber != null && carWash.plateNumber!.isNotEmpty)
              Text(
                'Plate: ${carWash.plateNumber}',
                style: TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              DateFormat('MMM dd, HH:mm').format(carWash.date),
              style: TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (carWash.notes != null && carWash.notes!.isNotEmpty)
              Text(
                'Note: ${carWash.notes!}',
                style: TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Container(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ETB ${commission.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${responsibleWasher.percentage}%',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey,
                ),
                maxLines: 1,
              ),
              Text(
                'Total: ETB ${carWash.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 7,
                  color: Colors.green,
                ),
                maxLines: 1,
              ),
            ],
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
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
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
  double totalRevenue;
  double commission;
  int vehicleCount;

  WasherReport({
    required this.washer,
    required this.carWashes,
    required this.totalRevenue,
    required this.commission,
    required this.vehicleCount,
  });
}
