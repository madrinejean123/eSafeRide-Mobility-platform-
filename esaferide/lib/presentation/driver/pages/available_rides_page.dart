import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../data/services/ride_service.dart';
import '../../../data/services/location_updater.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/geocode_service.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/driver/pages/driver_ride_tracking_page.dart';

class AvailableRidesPage extends StatefulWidget {
  const AvailableRidesPage({super.key});

  @override
  State<AvailableRidesPage> createState() => _AvailableRidesPageState();
}

class _AvailableRidesPageState extends State<AvailableRidesPage> {
  final RideService _rideService = RideService();
  LocationUpdater? _updater;
  final Map<String, Map<String, String?>> _metaCache = {};

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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await _rideService.acceptRide(
      rideId: rideId,
      driverId: user.uid,
    );
    if (!ok) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Ride already taken')),
      );
      return;
    }
    // start location updates for this ride
    _updater?.stop();
    _updater = LocationUpdater(rideId: rideId);
    await _updater?.start();
    // ensure a chat exists between driver and student for this ride
    String? chatId;
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .get();
      final rideData = rideDoc.data();
      final sid = rideData != null ? rideData['studentId'] as String? : null;
      if (sid != null && sid.isNotEmpty) {
        chatId = await ChatService().createChatIfNotExists(a: user.uid, b: sid);
      }
    } catch (e) {
      // ignore chat creation errors; it is non-fatal
    }
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Ride accepted. Sharing location...')),
    );
    // Navigate to ride tracking/map so driver can see pickup and route
    if (!mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => DriverRideTrackingPage(rideId: rideId, chatId: chatId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Available Rides',
      child: FutureBuilder<String?>(
        future: FirebaseAuth.instance.currentUser == null
            ? Future.value(null)
            : _rideService.findActiveRideForDriver(
                FirebaseAuth.instance.currentUser!.uid,
              ),
        builder: (context, activeSnap) {
          if (activeSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeRideId = activeSnap.data;
          // If driver already has an active ride, don't show the pending list.
          if (activeRideId != null && activeRideId.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('You have an active job.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DriverRideTrackingPage(rideId: activeRideId),
                          ),
                        );
                      },
                      child: const Text('Go to active job'),
                    ),
                  ],
                ),
              ),
            );
          }

          // No active ride - show pending rides stream but filter out rides
          // this driver already rejected.
          return StreamBuilder<QuerySnapshot>(
            stream: _rideService.listenToPendingRides(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Error'));
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawDocs = snapshot.data!.docs;
              final user = FirebaseAuth.instance.currentUser;
              final uid = user?.uid;

              // Filter out rides that this driver already rejected
              final docs = rawDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>?;
                if (d == null) return false;
                if (uid == null) return true;
                final rejected = List<String>.from(d['rejectedDrivers'] ?? []);
                return !rejected.contains(uid);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No pending rides'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data() as Map<String, dynamic>;
                  final rideId = doc.id;
                  final special = d['specialNeeds'] as Map<String, dynamic>?;

                  Future<Map<String, String?>> resolveMeta() async {
                    if (_metaCache.containsKey(rideId)) {
                      return _metaCache[rideId]!;
                    }
                    String studentName = (d['studentName'] as String?) ?? '';
                    final sid = d['studentId'] as String?;
                    if ((studentName.isEmpty) && sid != null) {
                      final sdoc = await FirebaseFirestore.instance
                          .collection('students')
                          .doc(sid)
                          .get();
                      if (sdoc.exists && sdoc.data() != null) {
                        studentName =
                            (sdoc.data() as Map<String, dynamic>)['fullName']
                                as String? ??
                            sid;
                      } else {
                        studentName = sid;
                      }
                    }

                    String? pickupLabel;
                    String? destLabel;
                    final pickup = d['pickup'] as GeoPoint?;
                    final dest = d['destination'] as GeoPoint?;
                    if (pickup != null) {
                      pickupLabel = await resolveLabel(
                        pickup.latitude,
                        pickup.longitude,
                      );
                    }
                    if (dest != null) {
                      destLabel = await resolveLabel(
                        dest.latitude,
                        dest.longitude,
                      );
                    }

                    final meta = {
                      'studentName': studentName,
                      'pickup': pickupLabel,
                      'dest': destLabel,
                    };
                    _metaCache[rideId] = meta;
                    return meta;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: styledCard(
                      child: FutureBuilder<Map<String, String?>>(
                        future: resolveMeta(),
                        builder: (context, snap) {
                          final meta = snap.data;
                          final studentLabel =
                              (meta != null ? meta['studentName'] : null) ??
                              (d['studentId'] ?? 'Unknown');
                          final pickupLabel = meta != null
                              ? (meta['pickup'] ??
                                    '${(d['pickup'] as GeoPoint?)?.latitude},${(d['pickup'] as GeoPoint?)?.longitude}')
                              : 'Loading...';
                          final destLabel = meta != null
                              ? (meta['dest'] ??
                                    '${(d['destination'] as GeoPoint?)?.latitude},${(d['destination'] as GeoPoint?)?.longitude}')
                              : 'Loading...';

                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$studentLabel • Ride $rideId',
                                      style: sectionTitleStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Pickup: $pickupLabel',
                                      style: subtleStyle(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Destination: $destLabel',
                                      style: subtleStyle(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if ((special?['notes'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6.0,
                                        ),
                                        child: Text(
                                          'Notes: ${special?['notes']}',
                                          style: subtleStyle(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _accept(rideId),
                                    style: primaryButtonStyle(),
                                    child: const Text('Accept'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user == null) return;
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final ok = await _rideService.rejectRide(
                                        rideId: rideId,
                                        driverId: user.uid,
                                      );
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Ride rejected'
                                                : 'Unable to reject',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
