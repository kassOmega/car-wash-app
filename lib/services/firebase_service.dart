import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/car_wash.dart';
import '../models/customer.dart';
import '../models/equipment_usage.dart';
import '../models/expense.dart';
import '../models/money_collection.dart';
import '../models/price.dart';
import '../models/store_item.dart';
import '../models/user_role.dart'; // Make sure to import AppUser
import '../models/washer.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Authentication
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

// Add this method to your FirebaseService and call it once
  Future<void> fixMissingUidFields() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data['uid'] == null) {
          // Add the uid field using the document ID
          await doc.reference.update({
            'uid': doc.id,
          });
        }
      }
    } catch (e) {}
  }

  // NEW METHOD: Create User Profile (used by signUpWithRole)
  Future<void> createUserProfile(AppUser appUser) async {
    await _firestore.collection('users').doc(appUser.uid).set(appUser.toMap());
  }

  // Existing signUp method (keep for backward compatibility)
  Future<UserCredential> signUp(
      String email, String password, String role) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  Future<UserCredential> signUpWithRole({
    required String email,
    required String password,
    required String role,
    required String name,
    String? phone,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user profile with all details
    final appUser = AppUser(
      uid: userCredential.user!.uid,
      email: email,
      role: role,
      name: name,
      phone: phone,
      createdAt: DateTime.now(),
    );

    await createUserProfile(appUser);
    return userCredential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // NEW METHOD: Get User Profile
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data();

        // TEMPORARY FIX: If uid is missing, add it from the document ID
        if (data != null) {
          data['uid'] = data['uid'] ?? doc.id;
        }

        final appUser = AppUser.fromMap(data!);

        return appUser;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // NEW METHOD: Get Car Washes by Specific Washer
  Stream<List<CarWash>> getCarWashesByWasher(String washerId) {
    return _firestore
        .collection('car_washes')
        .where('washerId', isEqualTo: washerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList());
  }

  Future<void> deleteCarWash(String carWashId) async {
    await _firestore.collection('car_washes').doc(carWashId).delete();
  }

  Stream<List<CarWash>> getCarWashesByWasherAndDateRange(
      String washerId, DateTime start, DateTime end) {
    return _firestore
        .collection('car_washes')
        .where('washerId', isEqualTo: washerId)
        .orderBy('date', descending: true) // Use single field ordering
        .snapshots()
        .map((snapshot) {
      // Filter by date manually in memory
      final allCarWashes =
          snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList();

      return allCarWashes.where((carWash) {
        return carWash.date.isAfter(start.subtract(Duration(seconds: 1))) &&
            carWash.date.isBefore(end.add(Duration(days: 1)));
      }).toList();
    });
  }

  // Keep your existing method for backward compatibility
  Future<Map<String, dynamic>> getUserDocument(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  // Car Wash Operations
  Future<void> addCarWash(CarWash carWash) async {
    await _firestore
        .collection('car_washes')
        .doc(carWash.id)
        .set(carWash.toMap());
  }

  Stream<List<CarWash>> getCarWashes() {
    return _firestore
        .collection('car_washes')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList());
  }

  Stream<List<CarWash>> getCarWashesByDateRange(DateTime start, DateTime end) {
    return _firestore
        .collection('car_washes')
        .orderBy('date', descending: true) // Single field ordering
        .snapshots()
        .map((snapshot) {
      // Filter by date manually in memory
      final allCarWashes =
          snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList();

      return allCarWashes.where((carWash) {
        return carWash.date.isAfter(start.subtract(Duration(seconds: 1))) &&
            carWash.date.isBefore(end.add(Duration(days: 1)));
      }).toList();
    });
  }

  Future<void> updateCarWash(CarWash carWash) async {
    await _firestore
        .collection('car_washes')
        .doc(carWash.id)
        .update(carWash.toMap());
  }

// Washer update method
  Future<void> updateWasher(Washer washer) async {
    await _firestore.collection('washers').doc(washer.id).update({
      'name': washer.name,
      'phone': washer.phone,
      'percentage': washer.percentage,
      'isActive': washer.isActive,
    });
  }

// Customer update method
  Future<void> updateCustomer(Customer customer) async {
    await _firestore.collection('customers').doc(customer.id).update({
      'name': customer.name,
      'phone': customer.phone,
      'customerType': customer.customerType,
    });
  }
// Add to FirebaseService class

// Washer delete method
  Future<void> deleteWasher(String washerId) async {
    await _firestore.collection('washers').doc(washerId).delete();
  }

// Customer delete method
  Future<void> deleteCustomer(String customerId) async {
    await _firestore.collection('customers').doc(customerId).delete();
  }

  // Customer Operations
  Future<void> addCustomer(Customer customer) async {
    await _firestore
        .collection('customers')
        .doc(customer.id)
        .set(customer.toMap());
  }

  Stream<List<Customer>> getCustomers() {
    return _firestore.collection('customers').orderBy('name').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList());
  }

  // Washer Operations
  Future<void> addWasher(Washer washer) async {
    await _firestore.collection('washers').doc(washer.id).set(washer.toMap());
  }

  Stream<List<Washer>> getWashers() {
    return _firestore.collection('washers').orderBy('name').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Washer.fromMap(doc.data())).toList());
  }

  // Expense Operations
  Future<void> addExpense(Expense expense) async {
    await _firestore
        .collection('expenses')
        .doc(expense.id)
        .set(expense.toMap());
  }

  Stream<List<Expense>> getExpenses() {
    return _firestore
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList());
  }

  Stream<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) {
    return _firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList());
  }

  // prices
  // Price Operations - Comprehensive Methods
  Future<void> addPrice(Price price) async {
    try {
      await _firestore
          .collection('prices')
          .doc(price.vehicleType)
          .set(price.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePrice(Price price) async {
    try {
      await _firestore
          .collection('prices')
          .doc(price.vehicleType)
          .update(price.toMap());
    } catch (e) {
      rethrow;
    }
  }

// NEW: Bulk update prices method
  Future<void> updatePrices(List<Price> prices) async {
    try {
      final batch = _firestore.batch();

      for (final price in prices) {
        final priceRef = _firestore.collection('prices').doc(price.vehicleType);
        batch.set(priceRef, price.toMap());
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

// NEW: Update single price by vehicle type
  Future<void> updatePriceByVehicleType(
      String vehicleType, double newAmount) async {
    try {
      if (newAmount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      final price = Price(vehicleType: vehicleType, amount: newAmount);
      await _firestore
          .collection('prices')
          .doc(vehicleType)
          .update(price.toMap());
    } catch (e) {
      rethrow;
    }
  }

// NEW: Update multiple prices with map
  Future<void> updateMultiplePrices(Map<String, double> priceUpdates) async {
    try {
      final batch = _firestore.batch();

      priceUpdates.forEach((vehicleType, amount) {
        if (amount <= 0) {
          throw Exception('Amount for $vehicleType must be greater than 0');
        }

        final priceRef = _firestore.collection('prices').doc(vehicleType);
        final price = Price(vehicleType: vehicleType, amount: amount);
        batch.set(priceRef, price.toMap());
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

// NEW: Check if price exists before updating
  Future<bool> priceExists(String vehicleType) async {
    try {
      final doc = await _firestore.collection('prices').doc(vehicleType).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

// NEW: Update or create price (upsert)
  Future<void> upsertPrice(Price price) async {
    try {
      await _firestore
          .collection('prices')
          .doc(price.vehicleType)
          .set(price.toMap(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Price>> getPrices() {
    return _firestore
        .collection('prices')
        .orderBy('vehicleType')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Price.fromMap(doc.data())).toList());
  }

  Future<Price?> getPriceByVehicleType(String vehicleType) async {
    try {
      final doc = await _firestore.collection('prices').doc(vehicleType).get();
      if (doc.exists) {
        return Price.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

// NEW: Get all prices as a map for easy access
  Future<Map<String, double>> getPricesMap() async {
    try {
      final snapshot = await _firestore.collection('prices').get();
      final pricesMap = <String, double>{};

      for (final doc in snapshot.docs) {
        final price = Price.fromMap(doc.data());
        pricesMap[price.vehicleType] = price.amount;
      }

      return pricesMap;
    } catch (e) {
      return {};
    }
  }

// Initialize default prices (call this once in your app)
  Future<void> initializeDefaultPrices() async {
    try {
      final defaultPrices = [
        Price(vehicleType: 'Motorcycle', amount: 200),
        Price(vehicleType: 'Bajaj', amount: 400),
        Price(vehicleType: 'Car', amount: 500),
        Price(vehicleType: 'Isuzu', amount: 1000),
        Price(vehicleType: 'Sino', amount: 1500),
        Price(vehicleType: 'Lowbed', amount: 2400),
        Price(vehicleType: 'Bajaj-Body', amount: 300),
        Price(vehicleType: 'Car-Body', amount: 400),
        Price(vehicleType: 'Isuzu-Body', amount: 600),
        Price(vehicleType: 'Sino-Body', amount: 750),
        Price(vehicleType: 'Sino-Trailer', amount: 500),
      ];

      // Use batch write for better performance
      final batch = _firestore.batch();

      for (final price in defaultPrices) {
        final priceRef = _firestore.collection('prices').doc(price.vehicleType);
        batch.set(priceRef, price.toMap());
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

// NEW: Reset all prices to default
  Future<void> resetToDefaultPrices() async {
    try {
      await initializeDefaultPrices();
    } catch (e) {
      rethrow;
    }
  }

// NEW: Delete a price
  Future<void> deletePrice(String vehicleType) async {
    try {
      await _firestore.collection('prices').doc(vehicleType).delete();
    } catch (e) {
      rethrow;
    }
  }

// NEW: Get total number of price entries
  Future<int> getPriceCount() async {
    try {
      final snapshot = await _firestore.collection('prices').get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // Store Items Operations
  Future<void> addStoreItem(StoreItem item) async {
    await _firestore.collection('store_items').doc(item.id).set(item.toMap());
  }

  Future<void> updateStoreItem(StoreItem item) async {
    await _firestore
        .collection('store_items')
        .doc(item.id)
        .update(item.toMap());
  }

  Future<void> deleteStoreItem(String itemId) async {
    await _firestore.collection('store_items').doc(itemId).delete();
  }

  Stream<List<StoreItem>> getStoreItems() {
    return _firestore.collection('store_items').orderBy('name').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => StoreItem.fromMap(doc.data())).toList());
  }

  Future<StoreItem?> getStoreItem(String itemId) async {
    final doc = await _firestore.collection('store_items').doc(itemId).get();
    if (doc.exists) {
      return StoreItem.fromMap(doc.data()!);
    }
    return null;
  }

// Equipment Usage Operations
  Future<void> addEquipmentUsage(EquipmentUsage usage) async {
    try {
      final batch = _firestore.batch();

      // Add the usage record
      final usageRef = _firestore.collection('equipment_usage').doc(usage.id);
      batch.set(usageRef, usage.toMap());

      // Update store item stock - cashier needs read access to store_items
      final itemRef =
          _firestore.collection('store_items').doc(usage.storeItemId);
      batch.update(itemRef, {
        'currentStock': FieldValue.increment(-usage.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      // Provide more specific error handling
      if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception(
            'Permission denied. Please check your user permissions.');
      }
      rethrow;
    }
  }

  Future<void> markEquipmentUsageAsPaid(String usageId) async {
    await _firestore.collection('equipment_usage').doc(usageId).update({
      'isPaid': true,
      'paidDate': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<EquipmentUsage>> getEquipmentUsageByWasher(String washerId) {
    return _firestore
        .collection('equipment_usage')
        .where('washerId', isEqualTo: washerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EquipmentUsage.fromMap(doc.data()))
            .toList());
  }

  Stream<List<EquipmentUsage>> getUnpaidEquipmentUsage() {
    return _firestore
        .collection('equipment_usage')
        .where('isPaid', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      // Debug
      return snapshot.docs.map((doc) {
        // Debug
        return EquipmentUsage.fromMap(doc.data());
      }).toList();
    });
  }

  Stream<List<EquipmentUsage>> getEquipmentUsageByDateRange(
      DateTime start, DateTime end) {
    return _firestore
        .collection('equipment_usage')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EquipmentUsage.fromMap(doc.data()))
            .toList());
  }

// Get total outstanding amount for a washer
  Future<double> getWasherOutstandingAmount(String washerId) async {
    final snapshot = await _firestore
        .collection('equipment_usage')
        .where('washerId', isEqualTo: washerId)
        .where('isPaid', isEqualTo: false)
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      total += doc['totalAmount'] as double;
    }
    return total;
  }

  // Money Collection Operations
  Future<void> addMoneyCollection(MoneyCollection collection) async {
    await _firestore
        .collection('money_collections')
        .doc(collection.id)
        .set(collection.toMap());
  }

  Stream<List<MoneyCollection>> getMoneyCollections() {
    return _firestore
        .collection('money_collections')
        .orderBy('collectionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MoneyCollection.fromMap(doc.data()))
            .toList());
  }

  Stream<List<MoneyCollection>> getMoneyCollectionsByDateRange(
      DateTime start, DateTime end) {
    return _firestore
        .collection('money_collections')
        .where('collectionDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('collectionDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('collectionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MoneyCollection.fromMap(doc.data()))
            .toList());
  }

// Get total collected amount for a specific date
  Future<double> getTotalCollectedForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('money_collections')
        .where('collectionDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('collectionDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs.fold(0.0, (sum, doc) {
      return (sum as double) + (doc['totalAmount'] as num).toDouble();
    });
  }
}
