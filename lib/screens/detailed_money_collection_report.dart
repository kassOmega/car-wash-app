// screens/detailed_money_collection_report.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/money_collection.dart';
import '../services/firebase_service.dart';

class DetailedMoneyCollectionReport extends StatelessWidget {
  final DateTimeRange dateRange;

  const DetailedMoneyCollectionReport({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Money Collection Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<MoneyCollection>>(
        stream: firebaseService.getMoneyCollectionsByDateRange(
            dateRange.start, dateRange.end),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final collections = snapshot.data ?? [];
          final totalCollected = collections.fold(
              0.0, (sum, collection) => sum + collection.totalAmount);

          // Group by collector
          final Map<String, List<MoneyCollection>> groupedByCollector = {};
          for (final collection in collections) {
            if (!groupedByCollector.containsKey(collection.collectedByName)) {
              groupedByCollector[collection.collectedByName] = [];
            }
            groupedByCollector[collection.collectedByName]!.add(collection);
          }

          return Column(
            children: [
              // Summary
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Collected',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                            Text(
                              'ETB ${totalCollected.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              '${collections.length} collections',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Icon(Icons.account_balance_wallet,
                            size: 40, color: Colors.green),
                      ],
                    ),
                  ),
                ),
              ),

              // Collections List
              Expanded(
                child: collections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No money collections found'),
                            SizedBox(height: 8),
                            Text('for the selected period'),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          ...groupedByCollector.entries.map((entry) {
                            final collectorName = entry.key;
                            final collectorCollections = entry.value;
                            final collectorTotal = collectorCollections.fold(
                                0.0,
                                (sum, collection) =>
                                    sum + collection.totalAmount);

                            return Card(
                              margin: EdgeInsets.all(8),
                              child: ExpansionTile(
                                leading:
                                    Icon(Icons.person, color: Colors.green),
                                title: Text(collectorName),
                                subtitle: Text(
                                    '${collectorCollections.length} collections - ETB ${collectorTotal.toStringAsFixed(2)}'),
                                children: [
                                  ...collectorCollections.map((collection) {
                                    return ListTile(
                                      leading: Icon(
                                          Icons.account_balance_wallet,
                                          color: Colors.blue),
                                      title: Text(
                                          'ETB ${collection.totalAmount.toStringAsFixed(2)}'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(DateFormat('MMM dd, yyyy')
                                              .format(
                                                  collection.collectionDate)),
                                          if (collection.notes != null)
                                            Text('Notes: ${collection.notes!}'),
                                        ],
                                      ),
                                      trailing: Text(
                                        DateFormat('HH:mm')
                                            .format(collection.createdAt),
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
