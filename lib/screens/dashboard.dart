import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'car_wash_entry.dart';
import 'customer_management.dart';
import 'expense_tracking.dart';
import 'reports.dart';
import 'washer_management.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfToday = today.add(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Wash Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Use the owner check for all menu items in the app bar for simplicity
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await firebaseService.signOut();
              }
              // Add other owner actions here if needed, like User Management
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting and Role Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome, ${authProvider.appUser?.name ?? 'User'}!',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getRoleDisplayName(authProvider.appUser?.role),
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Today: ${now.toLocal().toString().split(' ')[0]}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // --- Quick Stats Section (Nested StreamBuilders for Washes and Expenses) ---
            if (authProvider.isOwner || authProvider.isCashier)
              _buildStatsSection(context, firebaseService, today, endOfToday),

            // Main Menu Grid
            const SizedBox(height: 30),
            Expanded(
              child: _buildMenuGrid(context, authProvider),
            ),
          ],
        ),
      ),
    );
  }

  // New method for the Quick Stats section using nested StreamBuilders
  Widget _buildStatsSection(BuildContext context,
      FirebaseService firebaseService, DateTime today, DateTime endOfToday) {
    // Outer Stream: Car Washes (Revenue and Wash Count)
    return StreamBuilder<List<dynamic>>(
      stream: firebaseService.getCarWashesByDateRange(today, endOfToday),
      builder: (context, carWashSnapshot) {
        if (carWashSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }

        final totalWashes = carWashSnapshot.data?.length ?? 0;
        final totalRevenue = carWashSnapshot.data
                ?.fold(0.0, (sum, doc) => sum + (doc['amount'] as num)) ??
            0.0;

        // Inner Stream: Expenses (Only needed for Owner, but harmless for Cashier)
        return StreamBuilder<List<dynamic>>(
          stream: firebaseService.getExpensesByDateRange(today, endOfToday),
          builder: (context, expenseSnapshot) {
            if (expenseSnapshot.connectionState == ConnectionState.waiting) {
              // Show the progress bar *only* if the outer stream is done but inner is loading
              return const Center(child: LinearProgressIndicator());
            }

            final totalExpenses = expenseSnapshot.data
                    ?.fold(0.0, (sum, doc) => sum + (doc['amount'] as num)) ??
                0.0;

            final netProfit = totalRevenue - totalExpenses;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Summary',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true, // Important for GridView inside a Column
                  physics:
                      const NeverScrollableScrollPhysics(), // Prevent GridView from scrolling
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio:
                      1.8, // Adjust aspect ratio for a nice card size
                  children: [
                    _buildStatCard('Vehicles Washed', '$totalWashes',
                        Colors.blue.shade700),
                    _buildStatCard(
                        'Total Revenue',
                        '\$${totalRevenue.toStringAsFixed(2)}',
                        Colors.green.shade700),
                    // Only show Expenses/Profit to Owner, or if Cashier can see them
                    // Since the Stream is active, we display them but adjust colors.
                    _buildStatCard(
                        'Total Expenses',
                        '-\$${totalExpenses.toStringAsFixed(2)}',
                        Colors.red.shade700),
                    _buildStatCard(
                        'Net Profit',
                        '\$${netProfit.toStringAsFixed(2)}',
                        netProfit >= 0
                            ? Colors.green.shade500
                            : Colors.red.shade500),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper method to build the main grid content based on user role
  Widget _buildMenuGrid(BuildContext context, AuthProvider authProvider) {
    List<Widget> menuItems = [];

    // 1. Car Wash Entry (Cashier/Owner)
    if (authProvider.isOwner || authProvider.isCashier) {
      menuItems.add(
          _buildMenuCard('Record Wash', Icons.local_car_wash, Colors.blue, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const CarWashEntry()));
      }));
    }

    // 2. Customer Management (Owner)
    if (authProvider.isOwner) {
      menuItems.add(_buildMenuCard('Customers', Icons.people, Colors.green, () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CustomerManagement()));
      }));
    }

    // 3. Washer Management (Owner)
    if (authProvider.isOwner) {
      menuItems.add(
          _buildMenuCard('Washers', Icons.verified_user, Colors.orange, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const WasherManagement()));
      }));
    }

    // 4. Expense Tracking (Owner)
    if (authProvider.isOwner) {
      menuItems.add(_buildMenuCard('Expenses', Icons.money_off, Colors.red, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const ExpenseTracking()));
      }));
    }

    // All roles can view reports (but with different data access)
    menuItems.add(_buildMenuCard('Reports', Icons.analytics, Colors.purple, () {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const Reports()));
    }));

    // Adjust grid count based on number of items
    int crossAxisCount = menuItems.length <= 4 ? 2 : 3;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: menuItems,
    );
  }

  // Card builder for Menu Items
  Widget _buildMenuCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // Card builder for Daily Stats
  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'cashier':
        return 'Cashier';
      case 'washer':
        return 'Washer';
      default:
        return 'Guest';
    }
  }
}
