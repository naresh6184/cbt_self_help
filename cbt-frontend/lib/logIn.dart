import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '/signUp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgotPassword.dart';
import 'home.dart';
import 'db_helper.dart';
import 'walkthrough/walkthrough_page.dart'; // ⭐ NEW

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool obscurePass = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  // =========================================================
  // ⭐ NEW: Decide where to go after login
  // =========================================================
  Future<void> _navigateAfterLogin(User user) async {
    /// ⭐ STEP 1 — ALWAYS CHECK FIREBASE FIRST TIME
    /// because getWalkthroughCompleted() never returns null

    bool localWalkthrough = await DBHelper.getWalkthroughCompleted();

    bool completed;

    if (localWalkthrough) {
      /// Already completed locally
      completed = true;
    } else {
      /// Need to verify from Firebase
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      completed = doc.data()?['walkthroughCompleted'] ?? false;

      /// Save locally so next time it's instant
      await DBHelper.setWalkthroughCompleted(completed);
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        completed ? const HomePage() : const WalkthroughPage(),
      ),
    );
  }

  // =========================================================
  // ⭐ AUTO LOGIN
  // =========================================================
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('rememberMe') ?? false;

    if (!remember) return;

    final savedEmail = prefs.getString('email');
    final savedPassword = prefs.getString('password');

    if (savedEmail == null || savedPassword == null) return;

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: savedEmail,
        password: savedPassword,
      );

      final user = cred.user;

      if (user != null) {
        await _navigateAfterLogin(user);
      }
    } on FirebaseAuthException catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // =========================================================
  // SAVE REMEMBER ME
  // =========================================================
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }
  }

  // =========================================================
  // LOGIN BUTTON
  // =========================================================
  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        if (!user.emailVerified) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Please verify your email before logging in.")),
          );

          await user.sendEmailVerification();
          return;
        }

        await _saveCredentials();

        /// ⭐ IMPORTANT: NEW NAVIGATION LOGIC
        await _navigateAfterLogin(user);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = "";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password provided.";
      } else {
        message = "Login failed. ${e.message}";
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Login",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              /// EMAIL
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  labelText: "Email",
                ),
              ),
              const SizedBox(height: 16),

              /// PASSWORD
              TextField(
                controller: _passwordController,
                obscureText: obscurePass,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.password),
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePass
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePass = !obscurePass;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              /// REMEMBER ME
              Row(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text("Remember Me"),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text("Forgot Password?"),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// LOGIN BUTTON
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Login",
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 16),

              /// SIGNUP
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignUpPage()),
                  );
                },
                child: const Text("Don't have an account? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
