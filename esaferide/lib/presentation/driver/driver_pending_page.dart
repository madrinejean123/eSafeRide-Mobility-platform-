import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:esaferide/config/routes.dart';
import 'pages/driver_profile.dart';

class DriverPendingPage extends StatefulWidget {
  final String uid;
  const DriverPendingPage({super.key, required this.uid});

  @override
  State<DriverPendingPage> createState() => _DriverPendingPageState();
}

class _DriverPendingPageState extends State<DriverPendingPage> {
  bool _showDriverProfile = false;
  late String _uid;

  @override
  void initState() {
    super.initState();
    // Prefer the uid passed via arguments; otherwise fall back to the signed-in user.
    _uid = widget.uid.isNotEmpty
        ? widget.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    // If we still don't have a uid, redirect to login to avoid showing an empty page.
    if (_uid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeBackground = const Color(0xFFF2F6F9);
    return Scaffold(
      backgroundColor: themeBackground,
      appBar: AppBar(
        title: const Text('Driver — Pending Verification'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFB),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 12),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Profile pending verification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Thanks for registering. Your profile is under review by an administrator.\nYou will be able to access the dashboard once verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                setState(() => _showDriverProfile = true),
                            child: const Text('Edit / Submit profile'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.login,
                            ),
                            child: const Text('Logout'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showDriverProfile)
            DriverProfile(
              uid: _uid,
              onSave: () => setState(() => _showDriverProfile = false),
              onSkip: () => setState(() => _showDriverProfile = false),
            ),
        ],
      ),
    );
  }
}
