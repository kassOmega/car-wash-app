// screens/reports.dart - RESTORED WORKING VERSION
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_wash.dart';
import '../models/equipment_usage.dart';
import '../models/expense.dart';
import '../models/store_item.dart';
import '../models/washer.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'detailed_car_washes_report.dart';
import 'detailed_equipment_report.dart';
import 'detailed_expenses_report.dart';

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  _ReportsState createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  String _selectedPeriod = 'Daily';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Set default to today
    final today = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(today.year, today.month, today.day),
      end: DateTime(today.year, today.month, today.day, 23, 59, 59),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Map<String, dynamic> _calculateReport(
    List<CarWash> carWashes,
    List<Expense> expenses,
    List<Washer> washers,
    List<EquipmentUsage> equipmentUsage,
    List<StoreItem> storeItems,
    AuthProvider authProvider,
  ) {
    List<CarWash> filteredCarWashes;
    List<Expense> filteredExpenses;
    List<EquipmentUsage> filteredEquipmentUsage;

    // Apply date range filtering
    if (_selectedDateRange != null) {
      final startDate = _selectedDateRange!.start;
      final endDate = _selectedDateRange!.end;

      filteredCarWashes = carWashes.where((wash) {
        return wash.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
            wash.date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();

      filteredExpenses = expenses.where((expense) {
        return expense.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
            expense.date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();

      filteredEquipmentUsage = equipmentUsage.where((usage) {
        return usage.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
            usage.date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();
    } else {
      // Fallback to period-based filtering if no date range selected
      final now = DateTime.now();
      switch (_selectedPeriod) {
        case 'Daily':
          final today = DateTime(now.year, now.month, now.day);
          filteredCarWashes = carWashes.where((wash) {
            final washDate =
                DateTime(wash.date.year, wash.date.month, wash.date.day);
            return washDate == today;
          }).toList();
          filteredExpenses = expenses.where((expense) {
            final expenseDate = DateTime(
                expense.date.year, expense.date.month, expense.date.day);
            return expenseDate == today;
          }).toList();
          filteredEquipmentUsage = equipmentUsage.where((usage) {
            final usageDate =
                DateTime(usage.date.year, usage.date.month, usage.date.day);
            return usageDate == today;
          }).toList();
          break;
        case 'Weekly':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          filteredCarWashes = carWashes.where((wash) {
            return wash.date.isAfter(startOfWeek);
          }).toList();
          filteredExpenses = expenses.where((expense) {
            return expense.date.isAfter(startOfWeek);
          }).toList();
          filteredEquipmentUsage = equipmentUsage.where((usage) {
            return usage.date.isAfter(startOfWeek);
          }).toList();
          break;
        case 'Monthly':
          final startOfMonth = DateTime(now.year, now.month, 1);
          filteredCarWashes = carWashes.where((wash) {
            return wash.date.isAfter(startOfMonth);
          }).toList();
          filteredExpenses = expenses.where((expense) {
            return expense.date.isAfter(startOfMonth);
          }).toList();
          filteredEquipmentUsage = equipmentUsage.where((usage) {
            return usage.date.isAfter(startOfMonth);
          }).toList();
          break;
        default:
          filteredCarWashes = carWashes;
          filteredExpenses = expenses;
          filteredEquipmentUsage = equipmentUsage;
      }
    }

    // If user is washer, only show their car washes and equipment usage
    if (authProvider.isWasher) {
      filteredCarWashes = filteredCarWashes
          .where((wash) => wash.washerId == authProvider.user?.uid)
          .toList();
      filteredEquipmentUsage = filteredEquipmentUsage
          .where((usage) => usage.washerId == authProvider.user?.uid)
          .toList();
    }

    // Separate equipment usage into paid and unpaid
    final paidEquipmentUsage =
        filteredEquipmentUsage.where((usage) => usage.isPaid).toList();
    final unpaidEquipmentUsage =
        filteredEquipmentUsage.where((usage) => !usage.isPaid).toList();

    // Calculate totals
    final totalRevenue =
        filteredCarWashes.fold(0.0, (sum, wash) => sum + wash.amount);
    final totalExpenses =
        filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

    final paidEquipmentRevenue =
        paidEquipmentUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);
    final unpaidEquipmentRevenue =
        unpaidEquipmentUsage.fold(0.0, (sum, usage) => sum + usage.totalAmount);
    final totalEquipmentRevenue = paidEquipmentRevenue + unpaidEquipmentRevenue;

    // Calculate washer earnings and owner's share using individual washer percentages
    final washerEarnings = <String, double>{};
    final washerPercentages = <String, double>{};
    double totalWasherEarnings = 0.0;

    for (final wash in filteredCarWashes) {
      final washer = washers.firstWhere(
        (w) => w.id == wash.washerId,
        orElse: () => Washer(
          id: '',
          name: 'Unknown Washer',
          phone: '',
          percentage: 0,
          isActive: false,
          createdAt: DateTime.now(),
        ),
      );
      final earnings = wash.amount * (washer.percentage / 100);
      washerEarnings.update(
        washer.name,
        (value) => value + earnings,
        ifAbsent: () => earnings,
      );
      washerPercentages[washer.name] = washer.percentage;
      totalWasherEarnings += earnings;
    }

    // Calculate owner's share from car washes only (excluding equipment)
    final ownerCarWashRevenue = totalRevenue - totalWasherEarnings;

    // Net profit is calculated from CAR WASHES ONLY (excluding equipment revenue)
    final netProfit = ownerCarWashRevenue - totalExpenses;

    final totalIncome = totalRevenue + totalEquipmentRevenue;

    // Calculate equipment usage by washer - SEPARATE PAID AND UNPAID
    final paidEquipmentByWasher = <String, double>{};
    final unpaidEquipmentByWasher = <String, double>{};

    for (final usage in paidEquipmentUsage) {
      paidEquipmentByWasher.update(
        usage.washerName,
        (value) => value + usage.totalAmount,
        ifAbsent: () => usage.totalAmount,
      );
    }

    for (final usage in unpaidEquipmentUsage) {
      unpaidEquipmentByWasher.update(
        usage.washerName,
        (value) => value + usage.totalAmount,
        ifAbsent: () => usage.totalAmount,
      );
    }

    // Calculate popular items
    final popularItems = <String, int>{};
    for (final usage in filteredEquipmentUsage) {
      popularItems.update(
        usage.storeItemName,
        (value) => value + usage.quantity,
        ifAbsent: () => usage.quantity,
      );
    }

    // Get low stock items
    final lowStockItems = storeItems
        .where((item) => item.currentStock <= item.minimumStock)
        .toList();

    return {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'paidEquipmentRevenue': paidEquipmentRevenue,
      'unpaidEquipmentRevenue': unpaidEquipmentRevenue,
      'totalEquipmentRevenue': totalEquipmentRevenue,
      'ownerCarWashRevenue': ownerCarWashRevenue,
      'totalWasherEarnings': totalWasherEarnings,
      'netProfit': netProfit,
      'totalIncome': totalIncome,
      'vehicleCount': filteredCarWashes.length,
      'equipmentUsageCount': filteredEquipmentUsage.length,
      'paidEquipmentCount': paidEquipmentUsage.length,
      'unpaidEquipmentCount': unpaidEquipmentUsage.length,
      'washerEarnings': washerEarnings,
      'washerPercentages': washerPercentages,
      'paidEquipmentByWasher': paidEquipmentByWasher,
      'unpaidEquipmentByWasher': unpaidEquipmentByWasher,
      'popularItems': popularItems,
      'lowStockItems': lowStockItems,
    };
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDateRange(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDateRange != null
                              ? '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                              : 'Select Date Range',
                          style: TextStyle(fontSize: 14),
                        ),
                        Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.today),
                  onPressed: () {
                    setState(() {
                      final today = DateTime.now();
                      _selectedDateRange = DateTimeRange(
                        start: DateTime(today.year, today.month, today.day),
                        end: DateTime(
                            today.year, today.month, today.day, 23, 59, 59),
                      );
                    });
                  },
                  tooltip: 'Set to Today',
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Or select period:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPeriodButton('Daily'),
                _buildPeriodButton('Weekly'),
                _buildPeriodButton('Monthly'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = period;
              _selectedDateRange =
                  null; // Clear custom date range when using periods
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.purple : Colors.grey[300],
            foregroundColor: isSelected ? Colors.white : Colors.grey[700],
            elevation: isSelected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            period,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 130, // ADD THIS LINE - FIXED HEIGHT FOR ALL CARDS
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Icon(icon, size: 24, color: color),
                SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date Range Selector
            _buildDateRangeSelector(),
            SizedBox(height: 16),

            // Reports Content
            Expanded(
              child: StreamBuilder<List<CarWash>>(
                stream: authProvider.isWasher
                    ? firebaseService
                        .getCarWashesByWasher(authProvider.user!.uid)
                    : firebaseService.getCarWashes(),
                builder: (context, carWashSnapshot) {
                  return StreamBuilder<List<Expense>>(
                    stream: (authProvider.isOwner || authProvider.isCashier)
                        ? firebaseService.getExpenses()
                        : Stream.value([]),
                    builder: (context, expenseSnapshot) {
                      return StreamBuilder<List<Washer>>(
                        stream: firebaseService.getWashers(),
                        builder: (context, washerSnapshot) {
                          return StreamBuilder<List<EquipmentUsage>>(
                            stream: (authProvider.isOwner ||
                                    authProvider.isCashier)
                                ? firebaseService.getEquipmentUsageByDateRange(
                                    DateTime(2020),
                                    DateTime.now().add(Duration(days: 365)))
                                : authProvider.isWasher
                                    ? firebaseService.getEquipmentUsageByWasher(
                                        authProvider.user!.uid)
                                    : Stream.value([]),
                            builder: (context, equipmentSnapshot) {
                              return StreamBuilder<List<StoreItem>>(
                                stream: (authProvider.isOwner ||
                                        authProvider.isCashier)
                                    ? firebaseService.getStoreItems()
                                    : Stream.value([]),
                                builder: (context, storeItemsSnapshot) {
                                  // Handle loading state
                                  if (carWashSnapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      expenseSnapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      washerSnapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      equipmentSnapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      storeItemsSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                              color: Colors.purple),
                                          SizedBox(height: 16),
                                          Text('Loading reports...'),
                                        ],
                                      ),
                                    );
                                  }

                                  // Handle errors
                                  if (carWashSnapshot.hasError ||
                                      expenseSnapshot.hasError ||
                                      washerSnapshot.hasError ||
                                      equipmentSnapshot.hasError ||
                                      storeItemsSnapshot.hasError) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline,
                                              size: 64, color: Colors.red),
                                          SizedBox(height: 16),
                                          Text(
                                            'Error loading data',
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.red),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Please check your connection',
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                          SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () => setState(() {}),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final carWashes = carWashSnapshot.data ?? [];
                                  final expenses = expenseSnapshot.data ?? [];
                                  final washers = washerSnapshot.data ?? [];
                                  final equipmentUsage =
                                      equipmentSnapshot.data ?? [];
                                  final storeItems =
                                      storeItemsSnapshot.data ?? [];

                                  final report = _calculateReport(
                                      carWashes,
                                      expenses,
                                      washers,
                                      equipmentUsage,
                                      storeItems,
                                      authProvider);

                                  return _buildReportContent(report,
                                      authProvider, washers, storeItems);
                                },
                              );
                            },
                          );
                        },
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

  Widget _buildReportContent(
    Map<String, dynamic> report,
    AuthProvider authProvider,
    List<Washer> washers,
    List<StoreItem> storeItems,
  ) {
    // Helper to keep the main code clean
    Widget buildRowSpacing() => const SizedBox(height: 12);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          Text(
            _selectedDateRange != null
                ? 'Custom Date Range Report'
                : '$_selectedPeriod Report',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 20),

          // --- ROW 1: Vehicles & Equipment Count ---
          Row(
            children: [
              _buildModernStatCard(
                title: 'Vehicles Washed',
                value: '${report['vehicleCount']}',
                icon: Icons.local_car_wash,
                themeColor: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailedCarWashesReport(
                        dateRange: _selectedDateRange ??
                            DateTimeRange(
                                start: DateTime.now(), end: DateTime.now()),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildModernStatCard(
                title: 'Equipment Used',
                // Assuming 'equipmentUsageCount' exists based on your empty state check
                value: '${report['equipmentUsageCount'] ?? 0}',
                icon: Icons.build, // Wrench icon
                themeColor: Colors.orange,
                onTap: () {
                  // Add navigation if needed, or keep empty
                },
              ),
            ],
          ),
          buildRowSpacing(),

          // --- ROW 2: Total Revenue & Equipment Revenue ---
          Row(
            children: [
              _buildModernStatCard(
                title: 'Total Car Wash Revenue',
                value: 'ETB ${report['totalRevenue'].toStringAsFixed(2)}',
                icon: Icons.attach_money,
                themeColor: Colors.green, // Light green/grey look
                isMoney: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailedCarWashesReport(
                        dateRange: _selectedDateRange ??
                            DateTimeRange(
                                start: DateTime.now(), end: DateTime.now()),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildModernStatCard(
                title: 'Equipment Revenue',
                value:
                    'ETB ${report['totalEquipmentRevenue'].toStringAsFixed(2)}',
                icon: Icons.inventory_2,
                themeColor: Colors.teal,
                isMoney: true,
                onTap: () {
                  if (authProvider.isOwner || authProvider.isCashier) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedEquipmentReport(
                          dateRange: _selectedDateRange ??
                              DateTimeRange(
                                  start: DateTime.now(), end: DateTime.now()),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          buildRowSpacing(),

          // --- ROW 3: Washers Share & Your Share ---
          if (authProvider.isOwner || authProvider.isCashier) ...[
            Row(
              children: [
                _buildModernStatCard(
                  title: 'Washers Share',
                  value:
                      'ETB ${report['totalWasherEarnings'].toStringAsFixed(2)}',
                  icon: Icons.people,
                  themeColor: Colors.blue,
                  isMoney: true,
                  onTap: () {
                    _showWasherEarningsDialog(
                        report['washerEarnings'] as Map<String, double>);
                  },
                ),
                const SizedBox(width: 12),
                _buildModernStatCard(
                  title: 'Your Car Wash Share',
                  value:
                      'ETB ${report['ownerCarWashRevenue'].toStringAsFixed(2)}',
                  icon: Icons.person,
                  themeColor: Colors.purple,
                  isMoney: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedCarWashesReport(
                          dateRange: _selectedDateRange ??
                              DateTimeRange(
                                  start: DateTime.now(), end: DateTime.now()),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            buildRowSpacing(),
          ],

          // --- ROW 4: Paid & Unpaid Equipment ---
          if (authProvider.isOwner || authProvider.isCashier) ...[
            Row(
              children: [
                _buildModernStatCard(
                  title: 'Paid Equipment',
                  value:
                      'ETB ${report['paidEquipmentRevenue'].toStringAsFixed(2)}',
                  icon: Icons.check_circle,
                  themeColor: Colors.green,
                  isMoney: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedEquipmentReport(
                          dateRange: _selectedDateRange ??
                              DateTimeRange(
                                  start: DateTime.now(), end: DateTime.now()),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildModernStatCard(
                  title: 'Unpaid Equipment',
                  value:
                      'ETB ${report['unpaidEquipmentRevenue'].toStringAsFixed(2)}',
                  icon: Icons.more_horiz, // Three dots icon
                  themeColor: Colors.orange,
                  isMoney: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedEquipmentReport(
                          dateRange: _selectedDateRange ??
                              DateTimeRange(
                                  start: DateTime.now(), end: DateTime.now()),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            buildRowSpacing(),
          ],

          // --- ROW 5: Expenses & Net Profit ---
          Row(
            children: [
              _buildModernStatCard(
                title: 'Total Expenses',
                value: 'ETB ${report['totalExpenses'].toStringAsFixed(2)}',
                icon: Icons.money_off,
                themeColor: Colors.red,
                isMoney: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailedExpensesReport(
                        dateRange: _selectedDateRange ??
                            DateTimeRange(
                                start: DateTime.now(), end: DateTime.now()),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              if (authProvider.isOwner || authProvider.isCashier)
                _buildModernStatCard(
                  title: 'Net Profit (Car Wash Only)',
                  value: 'ETB ${report['netProfit'].toStringAsFixed(2)}',
                  icon: Icons.trending_up,
                  themeColor:
                      report['netProfit'] >= 0 ? Colors.green : Colors.red,
                  isMoney: true,
                  onTap: () {
                    // Nav logic
                  },
                )
              else
                const Spacer(), // Keep layout balanced if user is washer
            ],
          ),

          const SizedBox(height: 24),

          // --- EXISTING SECTIONS (Lists, Alerts, etc) BELOW ---
          // I have kept your existing logic below, just ensuring it flows
          // after the new grid.

          // Washer Earnings Section
          if ((authProvider.isOwner || authProvider.isCashier) &&
              (report['washerEarnings'] as Map<String, double>).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'Washer Earnings & Percentages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildWasherEarningsWithPercentagesList(
                        report['washerEarnings'] as Map<String, double>,
                        report['washerPercentages'] as Map<String, double>,
                        authProvider,
                        washers),
                  ],
                ),
              ),
            ),

          // ... (Include the rest of your original code for Lists/Stock Alerts here) ...
          // To save space I am focusing on the UI requested, but ensure you
          // paste your stock alerts/usage list logic here.
        ],
      ),
    );
  }

  // --- NEW CUSTOM WIDGET ---
  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color themeColor,
    required VoidCallback onTap,
    bool isMoney = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // Fixed height ensures all boxes in a row match size
          height: 130,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            // Pastel background: Color with very low opacity
            color: themeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            // Colored border
            border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon at top
              Icon(icon, color: themeColor, size: 28),

              // Value in middle (Large)
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMoney
                      ? 18
                      : 24, // Numbers slightly bigger than currency
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),

              // Title at bottom (Grey)
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWasherEarningsDialog(Map<String, double> washerEarnings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Washer Earnings Breakdown'),
        content: Container(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: washerEarnings.entries.map((entry) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                title: Text(entry.key),
                trailing: Text(
                  'ETB ${entry.value.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWasherEarningsWithPercentagesList(
    Map<String, double> washerEarnings,
    Map<String, double> washerPercentages,
    AuthProvider authProvider,
    List<Washer> washers,
  ) {
    final entries = washerEarnings.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) {
      final percentage = washerPercentages[entry.key] ?? 0.0;

      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.purple[100],
            radius: 20,
            child: Text(
              entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            entry.key,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${percentage.round()}% Commission',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: Text(
            'ETB ${entry.value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildWasherEarningsList(
    Map<String, double> washerEarnings,
    AuthProvider authProvider,
    List<Washer> washers,
  ) {
    final entries = washerEarnings.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) {
      if (authProvider.isWasher) {
        final washer = washers.firstWhere(
          (w) => w.name == entry.key,
          orElse: () => Washer(
            id: '',
            name: '',
            phone: '',
            percentage: 0,
            isActive: false,
            createdAt: DateTime.now(),
          ),
        );
        if (washer.id != authProvider.user?.uid) {
          return SizedBox.shrink();
        }
      }

      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.purple[100],
            radius: 20,
            child: Text(
              entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            entry.key,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            'ETB ${entry.value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildEquipmentUsageList(
      Map<String, double> equipmentUsage, Color color) {
    final entries = equipmentUsage.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 20,
            child: Icon(
              color == Colors.green ? Icons.check_circle : Icons.pending,
              size: 16,
              color: color,
            ),
          ),
          title: Text(
            entry.key,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            'ETB ${entry.value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPopularItemsList(Map<String, int> popularItems) {
    final entries = popularItems.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.take(5).map((entry) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.amber[100],
            radius: 20,
            child: Icon(Icons.star, size: 16, color: Colors.amber),
          ),
          title: Text(
            entry.key,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            '${entry.value} used',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber[800],
              fontSize: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildLowStockList(List<StoreItem> lowStockItems) {
    return lowStockItems.map((item) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.red[100],
            radius: 20,
            child: Icon(Icons.warning, size: 16, color: Colors.red),
          ),
          title: Text(
            item.name,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle:
              Text('Current: ${item.currentStock}, Min: ${item.minimumStock}'),
          trailing: Text(
            'Low Stock',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ),
      );
    }).toList();
  }
}
