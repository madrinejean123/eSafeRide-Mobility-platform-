// lib/presentation/auth/login_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:esaferide/config/routes.dart';

// Import the helper (the conditional import is inside this helper file)

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isObscurePassword = true;
  bool _isLoggingIn = false;

  late AnimationController _titleController;
  late Animation<Offset> _titleSlide;
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late AnimationController _buttonGradientController;
  late AnimationController _loadingController;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _titleController, curve: Curves.easeOut));

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _buttonGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _logoController.dispose();
    _buttonGradientController.dispose();
    _loadingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------- EMAIL LOGIN ----------------
  Future<void> _loginWithEmail() async {
    setState(() => _isLoggingIn = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _routeByRole(cred.user!.uid);
    } catch (e) {
      _showSnack(e.toString());
    }

    setState(() => _isLoggingIn = false);
  }

  // ---------------- GOOGLE LOGIN (platform-aware helper) ----------------
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoggingIn = true);

    try {
      final userCred = await signInWithGoogle();
      if (userCred == null) {
        setState(() => _isLoggingIn = false);
        return; // cancelled/no result
      }

      await _routeByRole(userCred.user!.uid);
    } catch (e) {
      _showSnack(e.toString());
    }

    setState(() => _isLoggingIn = false);
  }

  // ---------------- FACEBOOK LOGIN ----------------
  Future<void> _loginWithFacebook() async {
    setState(() => _isLoggingIn = true);

    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) {
        setState(() => _isLoggingIn = false);
        return;
      }

      // Access token property name sometimes differs across versions/platforms.
      final fbAccess = result.accessToken;
      final fbToken = fbAccess?.token ?? (fbAccess as dynamic)?.tokenString;
      if (fbToken == null) {
        _showSnack('Facebook access token missing');
        setState(() => _isLoggingIn = false);
        return;
      }

      final credential = FacebookAuthProvider.credential(fbToken);
      final userCred = await _auth.signInWithCredential(credential);
      await _routeByRole(userCred.user!.uid);
    } catch (e) {
      _showSnack(e.toString());
    }

    setState(() => _isLoggingIn = false);
  }

  // ---------------- ROLE ROUTING ----------------
  Future<void> _routeByRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();

    if (!snap.exists) {
      _showSnack('Account not found');
      return;
    }

    final data = snap.data();
    final rawRole = data == null ? null : data['role'];
    final role = rawRole?.toString().toLowerCase();

    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
    } else if (role == 'student') {
      Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard);
    } else {
      // default to driver dashboard for any other/unknown role
      Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF3E71DF);
    final Color primaryTeal = const Color(0xFF00BFA5);
    final Color accentOrange = const Color(0xFFFFA726);
    final Color accentPink = const Color(0xFFFFB6C1);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF143A44), Color(0xFF026D5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(50),
              ),
              child: Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height * 0.78,
                padding: const EdgeInsets.all(32),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _logoScale,
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SlideTransition(
                        position: _titleSlide,
                        child: Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _input('Email', Icons.email, _emailController),
                      const SizedBox(height: 16),
                      _password(),
                      const SizedBox(height: 24),
                      _loginButton(
                        primaryBlue,
                        primaryTeal,
                        accentOrange,
                        accentPink,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _social('assets/images/google.png', _loginWithGoogle),
                          const SizedBox(width: 16),
                          _social(
                            'assets/images/facebook.png',
                            _loginWithFacebook,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.register),
                        child: Text(
                          "Don't have an account? Register",
                          style: TextStyle(
                            color: primaryBlue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(String label, IconData icon, TextEditingController c) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFE0F7F4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _password() {
    return TextField(
      controller: _passwordController,
      obscureText: _isObscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () =>
              setState(() => _isObscurePassword = !_isObscurePassword),
        ),
      ),
    );
  }

  Widget _loginButton(Color a, Color b, Color c, Color d) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoggingIn ? null : _loginWithEmail,
        child: _isLoggingIn
            ? _LoadingDots(controller: _loadingController)
            : const Text('Login', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _social(String asset, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[200],
        child: Image.asset(asset, width: 24),
      ),
    );
  }

  Future signInWithGoogle() async {}
}

extension on AccessToken? {
  get token => null;
}

// ---------------- LOADER ----------------
class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final v = sin((controller.value * 2 * pi) + (i * 1.3));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              transform: Matrix4.translationValues(0, -v * 6, 0),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
