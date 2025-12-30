// lib/presentation/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/auth/login_page.dart';
import 'package:esaferide/presentation/auth/register_page.dart';
import 'package:esaferide/presentation/auth/splash_page.dart';
import 'package:esaferide/presentation/student/pages/student_dashboard.dart';
import 'package:esaferide/presentation/driver/pages/driver_dashboard.dart';
import 'package:esaferide/presentation/driver/driver_pending_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:esaferide/presentation/admin/admin_dashboard.dart';
import 'package:esaferide/presentation/chat/conversation_list_page.dart';
import 'package:esaferide/presentation/chat/user_list_page.dart';

class AppRoutes {
  // Basic routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Dashboard routes
  static const String studentDashboard = '/student_dashboard';
  static const String driverDashboard = '/driver_dashboard';
  static const String driverPending = '/driver_pending';
  static const String adminDashboard = '/admin_dashboard';
  static const String conversations = '/conversations';
  static const String usersList = '/users_list';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginPage(),
      register: (context) => const RegisterPage(),
      studentDashboard: (context) => const StudentDashboard(),
      driverDashboard: (context) => const DriverDashboard(),
      driverPending: (context) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        String uid = '';
        if (args != null && args['uid'] != null) {
          uid = args['uid'] as String;
        }
        if (uid.isEmpty) {
          uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        }
        return DriverPendingPage(uid: uid);
      },
      adminDashboard: (context) => const AdminDashboard(),
      conversations: (context) => const ConversationListPage(),
      usersList: (context) => const UserListPage(),
    };
  }

  // Placeholder for dynamic routing; kept to satisfy callers in main.dart.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return null;
  }
}
