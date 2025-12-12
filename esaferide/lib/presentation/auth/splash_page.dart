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
  late AnimationController _gradientController;

  bool _isLoading = false; // Loading indicator toggle

  @override
  void initState() {
    super.initState();

    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Gradient animation (not used for background anymore)
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _particleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  void _onGetStarted() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate a short loading period
    await Future.delayed(const Duration(seconds: 2));

    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: Listenable.merge([_particleController, _gradientController]),
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Fullscreen background image
              Positioned.fill(
                child: Image.asset(
                  'assets/images/safelogo.png',
                  fit: BoxFit.cover,
                ),
              ),

              // Floating particles
              ...List.generate(20, (i) {
                final progress = (_particleController.value + i / 20) % 1;
                final size = 5 + (sin(i * 30) + 1) * 5;
                return Positioned(
                  top: progress * screenHeight,
                  left: (sin(progress * 6.28 + i) * 80) + screenWidth / 2,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),

              // Floating shuttle & SafeBorder markers
              ...List.generate(6, (i) {
                final progress = (_particleController.value + i / 6) % 1;
                final iconSize = 20.0 + (i % 2) * 10;
                return Positioned(
                  top: progress * screenHeight,
                  left: (cos(progress * 6.28 + i) * 120) + screenWidth / 2,
                  child: Icon(
                    i % 2 == 0
                        ? Icons.directions_bus_filled
                        : Icons.location_on,
                    size: iconSize,
                    color: Colors.white.withOpacity(0.2),
                  ),
                );
              }),

              // Get Started button at bottom
              Positioned(
                bottom: screenHeight * 0.08,
                left: screenWidth * 0.2,
                right: screenWidth * 0.2,
                child: GestureDetector(
                  onTap: _isLoading ? null : _onGetStarted,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFFFDE047)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? SizedBox(
                            width: 60,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(3, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                );
                              }),
                            ),
                          )
                        : const Text(
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
      },
    );
  }
}
