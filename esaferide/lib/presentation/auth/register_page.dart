import 'package:flutter/material.dart';
import 'package:esaferide/config/routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  bool _isObscurePassword = true;
  bool _isObscureConfirm = true;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late AnimationController _buttonGradientController;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Button gradient animation
    _buttonGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonGradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF3E71DF);
    final Color primaryTeal = const Color(0xFF00BFA5);
    final Color accentOrange = const Color(0xFFFFA726);
    final Color accentPink = const Color(0xFFFFB6C1);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF143A44), Color(0xFF026D5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative circles at top
          _buildAnimatedCircle(-50, 60, 0.05, Colors.white, 20),
          _buildAnimatedCircle(100, 120, 0.04, Colors.white, 40),
          _buildAnimatedCircle(200, -40, 0.03, accentPink.withOpacity(0.2), 30),
          _buildAnimatedCircle(
            -80,
            200,
            0.04,
            primaryBlue.withOpacity(0.2),
            60,
          ),

          // Main curved container
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
              ),
              child: Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height * 0.78,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 30,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      ScaleTransition(
                        scale: _logoScale,
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      const Text(
                        'Empowering mobility for every student',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Page title
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Username Field
                      _buildInputField('Username', Icons.person, primaryBlue),
                      const SizedBox(height: 16),

                      // Email Field
                      _buildInputField(
                        'Email',
                        Icons.email,
                        primaryBlue,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      _buildInputField(
                        'Password',
                        Icons.lock,
                        primaryBlue,
                        obscureText: _isObscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: primaryBlue,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscurePassword = !_isObscurePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password Field
                      _buildInputField(
                        'Confirm Password',
                        Icons.lock_outline,
                        primaryBlue,
                        obscureText: _isObscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: primaryBlue,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscureConfirm = !_isObscureConfirm;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Animated gradient Register button
                      AnimatedBuilder(
                        animation: _buttonGradientController,
                        builder: (context, child) {
                          return Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(
                                    primaryBlue,
                                    primaryTeal,
                                    _buttonGradientController.value,
                                  )!,
                                  Color.lerp(
                                    primaryTeal,
                                    accentOrange,
                                    _buttonGradientController.value,
                                  )!,
                                  Color.lerp(
                                    accentOrange,
                                    accentPink,
                                    _buttonGradientController.value,
                                  )!,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.studentDashboard,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Social login row with equal size icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(
                            'assets/images/google.png',
                            primaryBlue,
                            primaryTeal,
                          ),
                          const SizedBox(width: 16),
                          _buildSocialButton(
                            'assets/images/facebook.png',
                            primaryBlue,
                            primaryTeal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Already have an account?
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.login);
                        },
                        child: Text(
                          "Already have an account? Login",
                          style: TextStyle(
                            color: primaryBlue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
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

  // Helper for input fields
  Widget _buildInputField(
    String label,
    IconData icon,
    Color borderColor, {
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: borderColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFE0F7F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
      ),
      style: const TextStyle(color: Colors.black87),
    );
  }

  // Helper for social buttons
  Widget _buildSocialButton(String asset, Color start, Color end) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [start, end]),
        boxShadow: [
          BoxShadow(
            color: start.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(asset, width: 24, height: 24, fit: BoxFit.contain),
      ),
    );
  }

  // Animated top circles
  Widget _buildAnimatedCircle(
    double top,
    double left,
    double opacity,
    Color color,
    double size,
  ) {
    return Positioned(
      top: top,
      left: left,
      child: AnimatedBuilder(
        animation: _buttonGradientController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 8 * (_buttonGradientController.value - 0.5)),
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}
