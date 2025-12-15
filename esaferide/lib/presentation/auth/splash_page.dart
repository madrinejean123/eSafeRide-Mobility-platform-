import 'dart:math';
import 'package:flutter/material.dart';
import 'package:esaferide/config/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _logoController;
  late AnimationController _loadingController;
  late AnimationController _typingController;

  late Animation<double> _logoPulse;

  bool _isLoading = false;

  final String _fullText =
      'Travel with confidence.\nEvery journey, safely guided.';
  String _displayedText = '';

  @override
  void initState() {
    super.initState();

    // Floating particles and shapes
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Logo pulse
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _logoPulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Loading dots
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Typewriter text
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(_typeText);

    Future.delayed(const Duration(milliseconds: 700), () {
      _typingController.forward();
    });
  }

  void _typeText() {
    final int charCount = (_typingController.value * _fullText.length).floor();
    setState(() {
      _displayedText = _fullText.substring(0, charCount);
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _logoController.dispose();
    _loadingController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void _onGetStarted() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Floating particles (small circles)
          ...List.generate(12, (i) {
            final progress = (_particleController.value + i / 12) % 1;
            return Positioned(
              top: progress * h,
              left: (sin(progress * 6.28 + i) * 70) + w / 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),

          // Floating decorative shapes (circles, squares, triangles)
          ...List.generate(8, (i) {
            final progress = (_particleController.value + i / 8) % 1;
            final topPosition = 50 + progress * h;
            final leftPosition = (i * 40.0) + sin(progress * 2 * pi) * 30;
            return Positioned(
              top: topPosition,
              left: leftPosition,
              child: Transform.rotate(
                angle: progress * pi * 2,
                child: _buildShape(i),
              ),
            );
          }),

          // Main content: Logo + Text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _logoPulse,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 34,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.25),
                        blurRadius: 35,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/safelogo.png', width: 180),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  _displayedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.8,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.6,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          // Bottom: Get Started button / loading dots
          Positioned(
            bottom: h * 0.08,
            left: w * 0.2,
            right: w * 0.2,
            child: _isLoading
                ? _LoadingDots(controller: _loadingController)
                : GestureDetector(
                    onTap: _onGetStarted,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFFFDE047)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Returns a decorative shape based on index
  Widget _buildShape(int index) {
    switch (index % 3) {
      case 0:
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
        );
      case 1:
        return Container(width: 12, height: 12, color: Colors.pinkAccent);
      default:
        return ClipPath(
          clipper: _TriangleClipper(),
          child: Container(width: 14, height: 14, color: Colors.orangeAccent),
        );
    }
  }
}

// Triangle shape for floating decorative triangle
class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0); // top
    path.lineTo(size.width, size.height); // bottom right
    path.lineTo(0, size.height); // bottom left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// THREE BALL LOADING ANIMATION
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
            final value = sin((controller.value * 2 * pi) + (i * 1.3));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              transform: Matrix4.translationValues(0, -value * 8, 0),
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
