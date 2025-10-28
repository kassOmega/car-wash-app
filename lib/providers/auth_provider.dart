import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  User? _user;
  AppUser? _appUser;

  AuthProvider(this._firebaseService) {
    _firebaseService.authStateChanges.listen((user) {
      _user = user;
      if (user != null) {
        _loadUserProfile();
      } else {
        _appUser = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _user != null;
  bool get isOwner => _appUser?.isOwner ?? false;
  bool get isCashier => _appUser?.isCashier ?? false;
  bool get isWasher => _appUser?.isWasher ?? false;

  Future<void> _loadUserProfile() async {
    if (_user != null) {
      try {
        _appUser = await _firebaseService.getUserProfile(_user!.uid);

        notifyListeners();
      } catch (e) {}
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
    String? phone,
  }) async {
    await _firebaseService.signUpWithRole(
      email: email,
      password: password,
      role: role,
      name: name,
      phone: phone,
    );
    if (_user != null) {
      await _loadUserProfile();
    }
  }

  Future<void> signIn(String email, String password) async {
    await _firebaseService.signIn(email, password);
    if (_user != null) {
      await _loadUserProfile();
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
  }
}
