import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/car_wash.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/user_role.dart';
import '../models/washer.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define the collection name for car washes
  static const String _carWashesCollection = 'carWashes';
  String getNewDocumentId(String collectionPath) {
    return _firestore.collection(collectionPath).doc().id;
  }

  Stream<List<CarWash>> getCarWashesByDateRange(DateTime start, DateTime end) {
    // Firestore stores date as Timestamp, so we convert the DateTime objects.
    return _firestore
        .collection('car_washes')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        // Order by date is crucial for this query to work properly with range filters
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList());
  }

  // Authentication
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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

  // User Management
  Future<void> createUserProfile(AppUser appUser) async {
    await _firestore.collection('users').doc(appUser.uid).set(appUser.toMap());
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromMap(doc.data()!);
    }
    return null;
  }

  // CarWash Operations
  Future<void> addCarWash(CarWash carWash) async {
    await _firestore
        .collection('carWashes')
        .doc(carWash.id)
        .set(carWash.toMap());
  }

  Stream<List<CarWash>> getCarWashes() {
    return _firestore
        .collection('carWashes')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList());
  }

  // CUSTOMER Operations
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

  // WASHER Operations
  Future<void> addWasher(Washer washer) async {
    await _firestore.collection('washers').doc(washer.id).set(washer.toMap());
  }

  // Method to update a Washer document
  Future<void> updateWasher(Washer washer) async {
    // Using set() will update the existing document or create it if it doesn't exist (upsert).
    await _firestore.collection('washers').doc(washer.id).set(washer.toMap());
  }

  // Method to delete a Washer document
  Future<void> deleteWasher(String washerId) async {
    await _firestore.collection('washers').doc(washerId).delete();
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

  Stream<List<CarWash>> getCarWashesByWasher(String washerId) {
    return _firestore
        .collection(_carWashesCollection)
        .where('washerId',
            isEqualTo: washerId) // Filters by the specific washer
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList());
  }
  // STATS/DASHBOARD Operations

  // Method requested by the user, now fetches CarWashes for a specific day
  Stream<List<CarWash>> getDailyStatsStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    // Use isLessThan the next day for a clean date range query
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('carWashes')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CarWash.fromMap(doc.data())).toList());
  }

  // Companion method to fetch expenses for the day
  Stream<List<Expense>> getDailyExpensesStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    // Use isLessThan the next day for a clean date range query
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList());
  }
}
