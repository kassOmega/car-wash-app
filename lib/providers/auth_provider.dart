import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  User? _user;
  AppUser? _appUser;
  bool _isProfileLoading = false; // New loading state

  AuthProvider(this._firebaseService) {
    _firebaseService.authStateChanges.listen((user) {
      _user = user;
      if (user != null) {
        _loadUserProfile();
      } else {
        _appUser = null;
        _isProfileLoading = false; // Reset when logged out
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _user != null;

  // New getter for the loading state
  bool get isProfileLoading => _isProfileLoading;

  bool get isOwner => _appUser?.isOwner ?? false;
  bool get isCashier => _appUser?.isCashier ?? false;
  bool get isWasher => _appUser?.isWasher ?? false;

  Future<void> _loadUserProfile() async {
    if (_user != null) {
      _isProfileLoading = true; // Start loading
      notifyListeners();

      _appUser = await _firebaseService.getUserProfile(_user!.uid);

      _isProfileLoading = false; // End loading
      notifyListeners();
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
    // After sign up, the authStateChanges listener above will trigger _loadUserProfile()
  }

  Future<void> signIn(String email, String password) async {
    await _firebaseService.signIn(
      email,
      password,
    );
    // After sign in, the authStateChanges listener above will trigger _loadUserProfile()
  }
}
