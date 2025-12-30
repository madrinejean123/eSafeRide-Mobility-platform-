import 'package:cloud_firestore/cloud_firestore.dart';

class RideService {
  final CollectionReference _ridesRef;

  RideService() : _ridesRef = FirebaseFirestore.instance.collection('rides');

  /// Create a new ride request. Returns the new rideId.
  Future<String> createRide({
    required String studentId,
    required GeoPoint pickup,
    required GeoPoint destination,
    Map<String, dynamic>? specialNeeds,
  }) async {
    final doc = await _ridesRef.add({
      'studentId': studentId,
      'pickup': pickup,
      'destination': destination,
      'specialNeeds': specialNeeds ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'rejectedDrivers': [], // track drivers who rejected
    });
    return doc.id;
  }

  /// Stream of pending rides (drivers can listen and filter by distance on client)
  Stream<QuerySnapshot> listenToPendingRides() {
    return _ridesRef.where('status', isEqualTo: 'pending').snapshots();
  }

  /// Attempt to accept a ride. Uses transaction to lock ride to one driver.
  Future<bool> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    final docRef = _ridesRef.doc(rideId);
    return FirebaseFirestore.instance
        .runTransaction((tx) async {
          final snapshot = await tx.get(docRef);
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final status = data['status'] as String? ?? 'pending';
          if (status != 'pending') return false; // already taken

          tx.update(docRef, {
            'driverId': driverId,
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          });
          return true;
        })
        .then((value) => value == true)
        .catchError((_) => false);
  }

  /// Reject a ride (mark driver as rejected so others can take it)
  Future<bool> rejectRide({
    required String rideId,
    required String driverId,
  }) async {
    final docRef = _ridesRef.doc(rideId);

    return FirebaseFirestore.instance
        .runTransaction((tx) async {
          final snapshot = await tx.get(docRef);
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data == null) return false;

          final status = data['status'] as String? ?? 'pending';
          if (status != 'pending') return false; // already taken

          final rejected = List<String>.from(data['rejectedDrivers'] ?? []);
          if (!rejected.contains(driverId)) {
            rejected.add(driverId);
          }

          tx.update(docRef, {'rejectedDrivers': rejected});
          return true;
        })
        .then((value) => value == true)
        .catchError((_) => false);
  }

  /// Listen to a specific ride document
  Stream<DocumentSnapshot> listenToRide(String rideId) {
    return _ridesRef.doc(rideId).snapshots();
  }

  /// Find an active ride ID assigned to the given driver (accepted/on_the_way/trip_started)
  Future<String?> findActiveRideForDriver(String driverId) async {
    final q = await _ridesRef
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'on_the_way', 'trip_started'])
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  /// Update the driver's current location for the ride. Also optionally advance status.
  Future<void> updateDriverLocation({
    required String rideId,
    required double latitude,
    required double longitude,
  }) async {
    final docRef = _ridesRef.doc(rideId);
    await docRef.update({
      'driverLocation': {
        'lat': latitude,
        'lng': longitude,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Optionally set status to on_the_way if currently accepted
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    if (data != null && (data['status'] as String?) == 'accepted') {
      await docRef.update({'status': 'on_the_way'});
    }
  }

  /// Update ride status (arrived, trip_started, completed, etc.)
  Future<void> updateStatus({
    required String rideId,
    required String status,
  }) async {
    final docRef = _ridesRef.doc(rideId);
    await docRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark a ride as completed and persist a trip summary in `trips`.
  /// Returns true if operation succeeded.
  Future<bool> completeTrip({
    required String rideId,
    required String driverId,
    required int durationSeconds,
    required double fare,
  }) async {
    final docRef = _ridesRef.doc(rideId);
    try {
      final snap = await docRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return false;

      // create a trip summary
      final tripsRef = FirebaseFirestore.instance.collection('trips');
      await tripsRef.add({
        'rideId': rideId,
        'driverId': driverId,
        'studentId': data['studentId'],
        'durationSeconds': durationSeconds,
        'fare': fare,
        'pickup': data['pickup'],
        'destination': data['destination'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // update ride status to completed
      await docRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
