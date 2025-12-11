import 'package:flutter/material.dart';
import 'dart:async';
import 'package:esaferide/config/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _vehicleController;

  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _vehicleAnimation;

  @override
  void initState() {
    super.initState();

    // Logo bounce/scale
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _logoAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Fade-in for title/subtitle
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();

    // Vehicle/wheel moving animation
    _vehicleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);
    _vehicleAnimation = Tween<double>(begin: -50.0, end: 50.0).animate(
      CurvedAnimation(parent: _vehicleController, curve: Curves.easeInOut),
    );

    // Navigate to login after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1B263B), // darker navy
              const Color(0xFF3B82F6), // lively blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Soft background circles
            Positioned(
              top: 80,
              left: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(90),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo
                  ScaleTransition(
                    scale: _logoAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.network(
                          'https://i.pinimg.com/originals/32/27/11/322711129569656440.png',
                          width: 80,
                          height: 80,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'eSafeRide',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Reliable mobility for all students',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Vehicle/wheel animation for loading
                  AnimatedBuilder(
                    animation: _vehicleController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_vehicleAnimation.value, 0),
                        child: Icon(
                          Icons.directions_bus_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
