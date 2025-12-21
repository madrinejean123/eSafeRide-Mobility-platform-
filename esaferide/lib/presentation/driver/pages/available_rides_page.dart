import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../data/services/ride_service.dart';
import '../../../data/services/location_updater.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';

class AvailableRidesPage extends StatefulWidget {
  const AvailableRidesPage({super.key});

  @override
  State<AvailableRidesPage> createState() => _AvailableRidesPageState();
}

class _AvailableRidesPageState extends State<AvailableRidesPage> {
  final RideService _rideService = RideService();
  LocationUpdater? _updater;

  @override
  void dispose() {
    _updater?.stop();
    super.dispose();
  }

  Future<void> _accept(String rideId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in required')));
      return;
    }
    final ok = await _rideService.acceptRide(
      rideId: rideId,
      driverId: user.uid,
    );
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride already taken')));
      return;
    }
    // start location updates for this ride
    _updater?.stop();
    _updater = LocationUpdater(rideId: rideId);
    await _updater?.start();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride accepted. Sharing location...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Available Rides',
      child: StreamBuilder<QuerySnapshot>(
        stream: _rideService.listenToPendingRides(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No pending rides'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>;
              final rideId = docs[index].id;
              final pickup = d['pickup'] as GeoPoint?;
              final dest = d['destination'] as GeoPoint?;
              final special = d['specialNeeds'] as Map<String, dynamic>?;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: styledCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ride $rideId', style: sectionTitleStyle()),
                            const SizedBox(height: 6),
                            Text(
                              'Pickup: ${pickup?.latitude},${pickup?.longitude} → Dest: ${dest?.latitude},${dest?.longitude}',
                              style: subtleStyle(),
                            ),
                            if ((special?['notes'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  'Notes: ${special?['notes']}',
                                  style: subtleStyle(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _accept(rideId),
                        style: primaryButtonStyle(),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
