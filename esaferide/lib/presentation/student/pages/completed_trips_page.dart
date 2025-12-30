import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompletedTripsPage extends StatefulWidget {
  const CompletedTripsPage({super.key});

  @override
  State<CompletedTripsPage> createState() => _CompletedTripsPageState();
}

class _CompletedTripsPageState extends State<CompletedTripsPage> {
  final Map<String, String> _driverNameCache = {};
  final Set<String> _resolving = {};

  Future<void> _resolveDriverName(String id) async {
    if (_driverNameCache.containsKey(id) || _resolving.contains(id)) return;
    _resolving.add(id);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(id)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _driverNameCache[id] = (data?['fullName'] as String?) ?? 'Driver';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _driverNameCache[id] = 'Driver';
      });
    } finally {
      _resolving.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    final tripsCol = FirebaseFirestore.instance
        .collection('trips')
        .where('studentId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('My Trips')),
      body: StreamBuilder<QuerySnapshot>(
        stream: tripsCol.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading trips'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No trips yet'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final driverId = data['driverId'] as String? ?? '';
              final fare = data['fare']?.toString() ?? '';
              final duration = (data['durationSeconds'] as int?) ?? 0;
              final created = data['createdAt'] as Timestamp?;

              // Resolve driver name async
              if (driverId.isNotEmpty &&
                  !_driverNameCache.containsKey(driverId) &&
                  !_resolving.contains(driverId)) {
                _resolveDriverName(driverId);
              }

              final driverName = driverId.isNotEmpty
                  ? (_driverNameCache[driverId] ?? 'Driver')
                  : 'Driver';

              final timeStr = created != null
                  ? TimeOfDay.fromDateTime(created.toDate()).format(context)
                  : '';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(driverName),
                subtitle: Text('Duration: ${duration}s • Fare: \$$fare'),
                trailing: Text(timeStr, style: const TextStyle(fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}
