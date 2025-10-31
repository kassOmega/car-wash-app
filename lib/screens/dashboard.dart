import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'car_wash_entry.dart';
import 'customer_management.dart';
import 'equipment_usage_screen.dart';
import 'expense_tracking.dart';
import 'prices_list_screen.dart';
import 'reports.dart';
import 'store_items_management.dart';
import 'user_registration.dart';
import 'washer_management.dart';
import 'washer_reports.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text('Car Wash Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (authProvider.isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  firebaseService.signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            )
          else
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await firebaseService.signOut();
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('car_washes')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
            .snapshots(),
        builder: (context, snapshot) {
          int todayCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
          double todayRevenue = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              todayRevenue += (doc['amount'] as num).toDouble();
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Today's summary (visible only to Owner and Washer, hidden from Cashier)
                if (authProvider.isOwner || authProvider.isWasher) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Today\'s Summary',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '$todayCount',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  ),
                                  Text('Vehicles Washed'),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'ETB ${todayRevenue.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  ),
                                  Text('Revenue'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Welcome message for Cashier (instead of summary)
                if (authProvider.isCashier) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.local_car_wash,
                              size: 48, color: Colors.blue),
                          SizedBox(height: 10),
                          Text(
                            'Welcome, ${authProvider.appUser?.name}!',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Ready to record car washes and manage operations',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Role-based menu grid
                Expanded(
                  child: _buildRoleBasedGrid(context, authProvider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleBasedGrid(BuildContext context, AuthProvider authProvider) {
    List<Widget> menuItems = [];

    // All roles can add car washes
    menuItems.add(
        _buildMenuCard('Add Car Wash', Icons.local_car_wash, Colors.blue, () {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => CarWashEntry()));
    }));

    // Owners and Cashiers can manage customers
    if (authProvider.isOwner || authProvider.isCashier) {
      menuItems.add(_buildMenuCard('Customers', Icons.people, Colors.green, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => CustomerManagement()));
      }));
    }

    // Only Owners can manage washers
    if (authProvider.isOwner) {
      menuItems.add(
          _buildMenuCard('Register User', Icons.person_add, Colors.teal, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => UserRegistrationScreen()));
      }));
      menuItems.add(_buildMenuCard('Washers', Icons.person, Colors.orange, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => WasherManagement()));
      }));
      menuItems.add(
          _buildMenuCard('Manage Prices', Icons.attach_money, Colors.amber, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => PricesListScreen()));
      }));
    }

    // Owners and Cashiers can track expenses
    if (authProvider.isOwner || authProvider.isCashier) {
      menuItems.add(_buildMenuCard('Expenses', Icons.money_off, Colors.red, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => ExpenseTracking()));
      }));
      menuItems.add(
          _buildMenuCard('Store Items', Icons.inventory_2, Colors.blue, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => StoreItemsManagement()));
      }));

      menuItems
          .add(_buildMenuCard('Issued Items', Icons.build, Colors.orange, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => EquipmentUsageScreen()));
      }));
    }

    if (authProvider.isOwner) {
      menuItems.add(
          _buildMenuCard('Washer Reports', Icons.assignment, Colors.teal, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => WasherReportsScreen()));
      }));
      menuItems
          .add(_buildMenuCard('Reports', Icons.analytics, Colors.purple, () {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => Reports()));
      }));
    }

    // Washer-specific menu items
    if (authProvider.isWasher) {
      menuItems
          .add(_buildMenuCard('My Reports', Icons.assignment, Colors.teal, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => WasherReportsScreen()));
      }));
    }

    int crossAxisCount = menuItems.length <= 4 ? 2 : 3;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: menuItems,
    );
  }

  Widget _buildMenuCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 10),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String? role) {
    if (role == null) return 'Loading...';
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'cashier':
        return 'Cashier';
      case 'washer':
        return 'Washer';
      default:
        return 'User';
    }
  }
}
