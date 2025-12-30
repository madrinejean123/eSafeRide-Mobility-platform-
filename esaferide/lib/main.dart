import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:esaferide/config/routes.dart';
import 'firebase_options.dart'; // 🔑 Import the generated Firebase options

Future<void> main() async {
  // Required for Firebase before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options for each platform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Better error logging so we can capture Flutter errors with full stacks
  FlutterError.onError = (FlutterErrorDetails details) {
    // Print to console immediately
    FlutterError.dumpErrorToConsole(details);
    // You can extend this to send errors to a logging service if desired
  };

  // Catch any uncaught asynchronous errors
  runZonedGuarded(
    () {
      runApp(const MyApp());
    },
    (error, stack) {
      // Print uncaught errors with stack
      // When you reproduce the ParentDataWidget error this will surface the full trace
      // so we can locate the offending widget and line.
      // Keep output concise but informative.
      // ignore: avoid_print
      print('Uncaught error: $error');
      // ignore: avoid_print
      print(stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSafeRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
