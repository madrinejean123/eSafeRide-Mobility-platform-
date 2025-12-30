// lib/presentation/auth/register_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:esaferide/config/routes.dart';

// helper

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isObscurePassword = true;
  bool _isObscureConfirm = true;
  bool _isRegistering = false;
  String? _selectedRole;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late AnimationController _buttonGradientController;
  late AnimationController _loadingController;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

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
    _logoController.dispose();
    _buttonGradientController.dispose();
    _loadingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ---------------- EMAIL REGISTER ----------------
  Future<void> _registerWithEmail() async {
    if (_selectedRole == null) {
      _showSnack('Select a role');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _saveUser(cred.user!);
      _goToDashboard(uid: cred.user!.uid);
    } catch (e) {
      _showSnack(e.toString());
    }

    setState(() => _isRegistering = false);
  }

  // ---------------- GOOGLE ----------------
  Future<void> _registerWithGoogle() async {
    if (_selectedRole == null) {
      _showSnack('Select a role first');
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final userCred = await signInWithGoogle();
      if (userCred == null) {
        setState(() => _isRegistering = false);
        return;
      }

      await _saveUser(userCred.user!);
      _goToDashboard(uid: userCred.user!.uid);
    } catch (e) {
      _showSnack(e.toString());
    }

    setState(() => _isRegistering = false);
  }

  // ---------------- FACEBOOK ----------------
  Future<void> _registerWithFacebook() async {
    if (_selectedRole == null) {
      _showSnack('Select a role first');
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) {
        setState(() => _isRegistering = false);
        return;
      }

      final fbAccess = result.accessToken;
      final fbToken = fbAccess?.token ?? (fbAccess as dynamic)?.tokenString;
      if (fbToken == null) {
        _showSnack('Facebook token missing');
        setState(() => _isRegistering = false);
        return;
      }

      final credential = FacebookAuthProvider.credential(fbToken);
      final userCred = await _auth.signInWithCredential(credential);

      await _saveUser(userCred.user!);
      _goToDashboard(uid: userCred.user!.uid);
    } catch (e) {
      _showSnack(e.toString());
    }

    setState(() => _isRegistering = false);
  }

  // ---------------- SAVE USER ----------------
  Future<void> _saveUser(User user) async {
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'name': _usernameController.text.isEmpty
          ? user.displayName
          : _usernameController.text,
      'role': _selectedRole,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // If registering as a driver, create an initial drivers/ doc so the
    // app can show the profile submission / pending verification flow
    if (_selectedRole == 'Driver') {
      await _db.collection('drivers').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'fullName': _usernameController.text.isEmpty
            ? user.displayName
            : _usernameController.text,
        'status': 'pending',
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Route to the correct dashboard/pending page using an explicit uid.
  // Passing the created user's uid avoids races where FirebaseAuth.currentUser
  // may not be populated consistently across platforms immediately after
  // registration.
  void _goToDashboard({required String uid}) {
    debugPrint('Routing after register: role=$_selectedRole uid=$uid');
    if (_selectedRole == 'Student') {
      Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard);
    } else {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.driverPending,
        arguments: {'uid': uid},
      );
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
                      const SizedBox(height: 20),
                      _input('Username', Icons.person, _usernameController),
                      const SizedBox(height: 12),
                      _input('Email', Icons.email, _emailController),
                      const SizedBox(height: 12),
                      _password('Password', _passwordController, true),
                      const SizedBox(height: 12),
                      _password('Confirm Password', _confirmController, false),
                      const SizedBox(height: 20),
                      _roleSelector(primaryBlue),
                      const SizedBox(height: 20),
                      _registerButton(
                        primaryBlue,
                        primaryTeal,
                        accentOrange,
                        accentPink,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _social(
                            'assets/images/google.png',
                            _registerWithGoogle,
                          ),
                          const SizedBox(width: 20),
                          _social(
                            'assets/images/facebook.png',
                            _registerWithFacebook,
                          ),
                        ],
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

  Widget _password(String label, TextEditingController c, bool main) {
    return TextField(
      controller: c,
      obscureText: main ? _isObscurePassword : _isObscureConfirm,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            main
                ? (_isObscurePassword ? Icons.visibility : Icons.visibility_off)
                : (_isObscureConfirm ? Icons.visibility : Icons.visibility_off),
          ),
          onPressed: () {
            setState(() {
              main
                  ? _isObscurePassword = !_isObscurePassword
                  : _isObscureConfirm = !_isObscureConfirm;
            });
          },
        ),
      ),
    );
  }

  Widget _roleSelector(Color c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['Student', 'Driver'].map((r) {
        final sel = _selectedRole == r;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ChoiceChip(
            label: Text(r),
            selected: sel,
            selectedColor: c,
            onSelected: (_) => setState(() => _selectedRole = r),
            labelStyle: TextStyle(color: sel ? Colors.white : c),
          ),
        );
      }).toList(),
    );
  }

  Widget _registerButton(Color a, Color b, Color c, Color d) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isRegistering ? null : _registerWithEmail,
        child: _isRegistering
            ? _LoadingDots(controller: _loadingController)
            : const Text('Register', style: TextStyle(fontSize: 18)),
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
