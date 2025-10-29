import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'providers/auth_provider.dart';
import 'screens/dashboard.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FirebaseOptions defaultFirebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyAFA1aV5qiFMW_s2IlW7Zrxvr12FLzLeKI",
    authDomain: "car-wash-management-app-6411d.firebaseapp.com",
    projectId: "car-wash-management-app-6411d",
    storageBucket: "car-wash-management-app-6411d.firebasestorage.app",
    messagingSenderId: "603095949351",

    /// based on platform give the correct app id
    appId: Platform.isIOS
        ? "1:603095949351:ios:7e5f047e4308d2be836e02"
        : kIsWeb
            ? "1:603095949351:web:dca06a65e2d21494836e02"
            : throw UnsupportedError(
                'Unsupported platform for Firebase initialization'),
    measurementId: "G-34CQSWF7ED",
  );
  await Firebase.initializeApp(options: defaultFirebaseOptions);

  final globalProviders = <SingleChildWidget>[
    Provider<FirebaseService>(
      create: (_) => FirebaseService(),
    ),
    ChangeNotifierProvider<AuthProvider>(
      create: (context) => AuthProvider(context.read<FirebaseService>()),
    ),
  ];

  runApp(
    MultiProvider(
      providers: globalProviders,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Wash Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait a moment for auth state to initialize
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authProvider.user == null) {
      return LoginScreen();
    }

    // Only show Dashboard if we have both user and appUser data
    if (authProvider.appUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading user profile...'),
            ],
          ),
        ),
      );
    }

    return Dashboard();
  }
}
