import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';

class AdminLiveMapPage extends StatefulWidget {
  const AdminLiveMapPage({super.key});

  @override
  State<AdminLiveMapPage> createState() => _AdminLiveMapPageState();
}

class _AdminLiveMapPageState extends State<AdminLiveMapPage> {
  final _rideCol = FirebaseFirestore.instance.collection('rides');
  GoogleMapController? _mapController;

  final Map<String, Marker> _markers = {};
  final Map<String, Polyline> _polylines = {};

  // Driver animation
  final Map<String, Timer?> _driverMoveTimers = {};
  final Map<String, List<LatLng>> _driverRoutePoints = {};
  final Map<String, int> _driverRouteIndex = {};
  final Map<String, LatLng> _currentPositions = {};

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(0.3476, 32.5825),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _listenToRides();
  }

  void _listenToRides() {
    _rideCol.snapshots().listen((snapshot) async {
      final docs = snapshot.docs;
      await _updateMarkersFromDocs(docs);
    });
  }

  Future<void> _updateMarkersFromDocs(List<QueryDocumentSnapshot> docs) async {
    final nextMarkers = <String, Marker>{};
    final nextPolylines = <String, Polyline>{};

    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final rideId = d.id;

      final pickup = data['pickup'] as GeoPoint?;
      final dest = data['destination'] as GeoPoint?;
      LatLng? pickupLatLng, destLatLng;

      if (pickup != null) {
        pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
      }
      if (dest != null) {
        destLatLng = LatLng(dest.latitude, dest.longitude);
      }

      // Driver location
      final driverLoc = data['driverLocation'];
      LatLng? driverLatLng;
      if (driverLoc != null) {
        final lat = (driverLoc['lat'] as num?)?.toDouble();
        final lng = (driverLoc['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          driverLatLng = LatLng(lat, lng);
        }
      }

      // Add markers
      if (pickupLatLng != null) {
        nextMarkers['$rideId-pickup'] = Marker(
          markerId: MarkerId('$rideId-pickup'),
          position: pickupLatLng,
          infoWindow: InfoWindow(title: 'Pickup • Ride $rideId'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );
      }
      if (destLatLng != null) {
        nextMarkers['$rideId-dest'] = Marker(
          markerId: MarkerId('$rideId-dest'),
          position: destLatLng,
          infoWindow: InfoWindow(title: 'Destination • Ride $rideId'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }
      if (driverLatLng != null) {
        final prev = _currentPositions[rideId];
        if (prev != null) {
          _animateDriverToRide(rideId, driverLatLng);
        }
        _currentPositions[rideId] = driverLatLng;
        nextMarkers['$rideId-driver'] = Marker(
          markerId: MarkerId('$rideId-driver'),
          position: driverLatLng,
          infoWindow: InfoWindow(title: 'Driver • Ride $rideId'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      }

      // Fetch pickup → destination route
      if (pickupLatLng != null && destLatLng != null) {
        final routePoints = await _getRoutePoints(pickupLatLng, destLatLng);
        if (routePoints.isNotEmpty) {
          nextPolylines['$rideId-route'] = Polyline(
            polylineId: PolylineId('$rideId-route'),
            points: routePoints,
            color: Colors.blueAccent,
            width: 5,
          );
        }
      }

      // Fetch driver → pickup route
      if (driverLatLng != null && pickupLatLng != null) {
        final driverRoutePoints = await _getRoutePoints(
          driverLatLng,
          pickupLatLng,
        );
        if (driverRoutePoints.isNotEmpty) {
          nextPolylines['$rideId-driver'] = Polyline(
            polylineId: PolylineId('$rideId-driver'),
            points: driverRoutePoints,
            color: Colors.orange,
            width: 4,
            patterns: [PatternItem.dash(10), PatternItem.gap(6)],
          );
        }
      }
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(nextMarkers);
      _polylines
        ..clear()
        ..addAll(nextPolylines);
    });
  }

  Future<List<LatLng>> _getRoutePoints(LatLng start, LatLng end) async {
    const apiKey = 'AIzaSyApNrcg8oYtgww7uJnMaMXYz7lgyvX5aNc';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? [];
      if (routes.isEmpty) return [];

      final overview = routes[0]['overview_polyline'];
      if (overview != null && overview['points'] is String) {
        return _decodePolyline(overview['points']);
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  List<LatLng> _interpolatePoints(LatLng start, LatLng end, int steps) {
    final points = <LatLng>[];
    for (int i = 1; i <= steps; i++) {
      points.add(
        LatLng(
          start.latitude + (end.latitude - start.latitude) * i / steps,
          start.longitude + (end.longitude - start.longitude) * i / steps,
        ),
      );
    }
    return points;
  }

  void _animateDriverToRide(String rideId, LatLng newPos) {
    final prev = _currentPositions[rideId];
    if (prev == null) return;

    final points = _interpolatePoints(prev, newPos, 20);
    _driverRoutePoints[rideId] = points;
    _driverRouteIndex[rideId] = 0;
    _driverMoveTimers[rideId]?.cancel();
    _driverMoveTimers[rideId] = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final idx = _driverRouteIndex[rideId] ?? 0;
        if (idx >= points.length) {
          timer.cancel();
          _driverMoveTimers.remove(rideId);
          _driverRoutePoints.remove(rideId);
          _driverRouteIndex.remove(rideId);
          _currentPositions[rideId] = newPos;
          return;
        }
        final pos = points[idx];
        _driverRouteIndex[rideId] = idx + 1;
        final key = '$rideId-driver';
        setState(() {
          final old = _markers[key];
          if (old != null) {
            _markers[key] = old.copyWith(positionParam: pos);
          }
        });

        // Move camera along with driver
        _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Live Map',
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: GoogleMap(
            initialCameraPosition: _initialCamera,
            markers: _markers.values.toSet(),
            polylines: _polylines.values.toSet(),
            mapType: MapType.normal,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
        ),
      ),
    );
  }
}
