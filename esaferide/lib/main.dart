import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:esaferide/config/routes.dart';
import 'firebase_options.dart'; // 🔑 Import the generated Firebase options

Future<void> main() async {
  // Required for Firebase before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options for each platform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
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
