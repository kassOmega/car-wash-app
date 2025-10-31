import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  User? _user;
  AppUser? _appUser;
  bool _profileLoading = false;
  String? _error;

  AuthProvider(this._firebaseService) {
    _firebaseService.authStateChanges.listen((user) {
      _user = user;
      if (user != null) {
        _loadUserProfile();
      } else {
        _appUser = null;
        _profileLoading = false;
        _error = null;
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
  bool get profileLoading => _profileLoading;
  String? get error => _error;

  Future<void> _loadUserProfile() async {
    if (_user != null) {
      try {
        _profileLoading = true;
        _error = null;
        notifyListeners();

        _appUser = await _firebaseService.getUserProfile(_user!.uid);

        if (_appUser == null) {
          _error = 'User profile not found';
          if (kDebugMode) {
            print('❌ User profile not found for UID: ${_user!.uid}');
          }
        }
      } catch (e) {
        _error = 'Failed to load user profile: $e';
        if (kDebugMode) {
          print('❌ Error loading user profile: $e');
        }
      } finally {
        _profileLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
    String? phone,
  }) async {
    try {
      _error = null;
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
    } catch (e) {
      _error = 'Sign up failed: $e';
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      _error = null;
      await _firebaseService.signIn(email, password);
      if (_user != null) {
        await _loadUserProfile();
      }
    } catch (e) {
      _error = 'Sign in failed: $e';
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    _error = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
