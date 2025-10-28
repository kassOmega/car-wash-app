import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;
  String _selectedRole = 'cashier';

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (mounted) setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (_isSignUp) {
          await authProvider.signUp(
            email: _emailController.text,
            password: _passwordController.text,
            role: _selectedRole,
            name: _nameController.text,
            phone:
                _phoneController.text.isNotEmpty ? _phoneController.text : null,
          );
        } else {
          await authProvider.signIn(
            _emailController.text,
            _passwordController.text,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }

      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_car_wash,
                        size: 64,
                        color: Colors.blue,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _isSignUp ? 'Create Account' : 'Car Wash Manager',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 24),
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_isSignUp && (value == null || value.isEmpty)) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (_isSignUp) ...[
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone (Optional)',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'owner', child: Text('Owner')),
                            DropdownMenuItem(
                                value: 'cashier', child: Text('Cashier')),
                            DropdownMenuItem(
                                value: 'washer', child: Text('Washer')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                      ],
                      SizedBox(height: 24),
                      if (_isLoading)
                        CircularProgressIndicator()
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                          });
                        },
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign In'
                              : 'Don\'t have an account? Sign Up',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
