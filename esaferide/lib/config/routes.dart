// lib/presentation/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/auth/login_page.dart';
import 'package:esaferide/presentation/auth/register_page.dart';
import 'package:esaferide/presentation/auth/splash_page.dart';
import 'package:esaferide/presentation/student/pages/student_dashboard.dart';
import 'package:esaferide/presentation/driver/pages/driver_dashboard.dart';

// Optional: if you want to import StudentProfile separately
// import 'package:esaferide/presentation/student/pages/student_profile.dart';

class AppRoutes {
  // Basic routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Dashboard routes
  static const String studentDashboard = '/student_dashboard';
  static const String driverDashboard = '/driver_dashboard';

  // Static routes map
  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginPage(),
      register: (context) => const RegisterPage(),
      studentDashboard: (context) => const StudentDashboard(),
      driverDashboard: (context) {
        // Obtain `uid` from the route arguments which may be either a String
        // or a Map containing a 'uid' key. Fall back to empty string if not found.
        final args = ModalRoute.of(context)?.settings.arguments;
        String uid;
        if (args is String) {
          uid = args;
        } else if (args is Map && args['uid'] is String) {
          uid = args['uid'] as String;
        } else {
          uid = '';
        }
        return DriverDashboard(uid: uid);
      },
    };
  }

  // onGenerateRoute can be used later if dynamic routing is needed
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return null; // No dynamic routes yet
  }
}
