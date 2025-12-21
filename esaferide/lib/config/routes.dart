// lib/presentation/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/auth/login_page.dart';
import 'package:esaferide/presentation/auth/register_page.dart';
import 'package:esaferide/presentation/auth/splash_page.dart';
import 'package:esaferide/presentation/student/pages/student_dashboard.dart';
import 'package:esaferide/presentation/driver/pages/driver_dashboard.dart';

class AppRoutes {
  // Basic routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Dashboard routes
  static const String studentDashboard = '/student_dashboard';
  static const String driverDashboard = '/driver_dashboard';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginPage(),
      register: (context) => const RegisterPage(),
      studentDashboard: (context) => const StudentDashboard(),
      driverDashboard: (context) => const DriverDashboard(),
    };
  }

  // Placeholder for dynamic routing; kept to satisfy callers in main.dart.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return null;
  }
}
