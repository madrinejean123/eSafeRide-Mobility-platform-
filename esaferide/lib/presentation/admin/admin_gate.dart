import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// AdminGate checks whether the current user is an admin before showing [child].
/// It checks first for custom claim `admin` on the ID token, then falls back to
/// Firestore document `users/{uid}.role == 'admin'` or `isAdmin == true`.
class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  Future<bool> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    // First try custom claim on the ID token
    try {
      final idToken = await user.getIdTokenResult(true);
      if (idToken.claims != null && idToken.claims!['admin'] == true) {
        return true;
      }
    } catch (_) {
      // ignore errors and fall back to Firestore check
    }

    // Fall back to Firestore users/{uid}
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null &&
          (data['role'] == 'admin' || data['isAdmin'] == true)) {
        return true;
      }
    } catch (_) {
      // ignore
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAdmin(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final ok = snap.data == true;
        if (!ok) {
          return Center(
            child: Text(
              'Access denied — admin only',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return child;
      },
    );
  }
}
