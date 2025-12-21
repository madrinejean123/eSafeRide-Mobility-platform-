import 'package:cloud_firestore/cloud_firestore.dart';

class Ride {
  final String id;
  final String studentId;
  final String? driverId;
  final GeoPoint pickup;
  final GeoPoint destination;
  final String status;
  final Map<String, dynamic>? driverLocation;
  final Map<String, dynamic>? specialNeeds;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  Ride({
    required this.id,
    required this.studentId,
    this.driverId,
    required this.pickup,
    required this.destination,
    required this.status,
    this.driverLocation,
    this.specialNeeds,
    required this.createdAt,
    this.updatedAt,
  });

  factory Ride.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Ride(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      driverId: data['driverId'] as String?,
      pickup: data['pickup'] as GeoPoint? ?? GeoPoint(0, 0),
      destination: data['destination'] as GeoPoint? ?? GeoPoint(0, 0),
      status: data['status'] as String? ?? 'pending',
      driverLocation: data['driverLocation'] as Map<String, dynamic>?,
      specialNeeds: data['specialNeeds'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'driverId': driverId,
      'pickup': pickup,
      'destination': destination,
      'status': status,
      'driverLocation': driverLocation,
      'specialNeeds': specialNeeds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
