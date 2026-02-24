// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _phone = ''; // optional
  bool _isLoading = false;

  // Independent visibility flags
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create user with email and password
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Send verification email
        await userCredential.user?.sendEmailVerification();

        // Save user data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'name': _name,
          'email': _email,
          'phone': _phone, // optional
          'createdAt': DateTime.now(),
          'weeklyActivity':-1,
          'walkthroughCompleted':false,
          'PHQ9ShowcaseCompleted':false,
          'homeShowcaseCompleted':false
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Verify your email to log in.'),
            duration: Duration(seconds: 3),
          ),
        );

        Future.delayed(const Duration(seconds: 3), () {
          Navigator.pop(context);
        });
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage =
            'This email is already in use. Please try logging in.';
            break;
          case 'weak-password':
            errorMessage = 'The password provided is too weak.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is not valid.';
            break;
          default:
            errorMessage = 'Sign Up failed: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.08,
            vertical: height * 0.02,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Register",
                  style: TextStyle(
                    fontSize: width * 0.07,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: height * 0.02),

                // Full Name (Required)
                _buildTextField(
                  'Full Name',
                  true,
                  'Enter your full name',
                  Icons.person,
                  false,
                      (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters long';
                    }
                    return null;
                  },
                      (value) {
                    _name = value;
                  },
                ),
                SizedBox(height: width * 0.04),

                // Email (Required)
                _buildTextField(
                  'Email',
                  true,
                  'Enter your email',
                  Icons.email,
                  false,
                      (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                      (value) {
                    _email = value;
                  },
                ),
                SizedBox(height: width * 0.04),

                // Mobile (Optional)
                _buildTextField(
                  'Mobile No.',
                  false,
                  'Enter your mobile number',
                  Icons.phone,
                  false,
                  null, // no validation
                      (value) {
                    _phone = value;
                  },
                ),
                SizedBox(height: width * 0.04),

                // Password (Required)
                _buildPasswordField(
                  'Password',
                  true,
                  'Enter your password',
                      (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters long';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                      return 'Password must contain at least one uppercase letter';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(value)) {
                      return 'Password must contain at least one lowercase letter';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(value)) {
                      return 'Password must contain at least one digit';
                    }
                    if (!RegExp(r'[\p{P}\p{S}]', unicode: true).hasMatch(value)) {
                      return 'Password must contain at least one special character.';
                    }
                    return null;
                  },
                      (value) {
                    _password = value;
                  },
                  _obscurePassword,
                      () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                SizedBox(height: width * 0.04),

                // Confirm Password (Required)
                _buildPasswordField(
                  'Confirm Password',
                  true,
                  'Re-enter your password',
                      (value) {
                    if (value != _password) return 'Passwords do not match';
                    return null;
                  },
                      (value) {
                    _confirmPassword = value;
                  },
                  _obscureConfirmPassword,
                      () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                SizedBox(height: width * 0.06),

                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                  width: double.infinity,
                  height: height * 0.07,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    child: const Text('Sign Up'),
                  ),
                ),
                SizedBox(height: width * 0.04),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Already have an account? Login'),
                ),
                SizedBox(height: height * 0.06),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Normal text field builder
  Widget _buildTextField(
      String label,
      bool required,
      String hint,
      IconData icon,
      bool obscureText,
      String? Function(String?)? validator,
      Function(String)? onChanged,
      ) {
    return TextFormField(
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black),
            children: required
                ? const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ]
                : [],
          ),
        ),
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
    );
  }

  /// Password field builder
  Widget _buildPasswordField(
      String label,
      bool required,
      String hint,
      String? Function(String?)? validator,
      Function(String)? onChanged,
      bool obscureFlag,
      VoidCallback toggleVisibility,
      ) {
    return TextFormField(
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black),
            children: required
                ? const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ]
                : [],
          ),
        ),
        hintText: hint,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            obscureFlag ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: toggleVisibility,
        ),
        border: const OutlineInputBorder(),
      ),
      obscureText: obscureFlag,
      validator: validator,
      onChanged: onChanged,
    );
  }
}
