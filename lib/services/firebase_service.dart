import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/car_wash.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/price.dart';
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
          print('Fixed user document: ${doc.id}');
        }
      }
      print('All user documents have been updated with uid fields');
    } catch (e) {
      print('Error fixing user documents: $e');
    }
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
      print('Fetching user profile from Firestore for UID: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      print('Document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data();
        print('Raw user data from Firestore: $data');

        // TEMPORARY FIX: If uid is missing, add it from the document ID
        if (data != null) {
          data['uid'] = data['uid'] ?? doc.id;
          print('Added uid to data: ${data['uid']}');
        }

        final appUser = AppUser.fromMap(data!);
        print('Parsed AppUser: $appUser');

        return appUser;
      } else {
        print('ERROR: No user document found for UID: $uid');
        return null;
      }
    } catch (e) {
      print('Error in getUserProfile: $e');
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
  // Add to your FirebaseService class

// Price Operations
  Future<void> addPrice(Price price) async {
    await _firestore
        .collection('prices')
        .doc(price.vehicleType)
        .set(price.toMap());
  }

  Future<void> updatePrice(Price price) async {
    await _firestore
        .collection('prices')
        .doc(price.vehicleType)
        .update(price.toMap());
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
    final doc = await _firestore.collection('prices').doc(vehicleType).get();
    if (doc.exists) {
      return Price.fromMap(doc.data()!);
    }
    return null;
  }

// Initialize default prices (call this once in your app)
  Future<void> initializeDefaultPrices() async {
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

    for (final price in defaultPrices) {
      await addPrice(price);
    }
  }
}
