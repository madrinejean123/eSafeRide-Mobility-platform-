import 'dart:async';
import 'dart:convert';
// 'dart:math' was unused and removed to satisfy lints

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../data/services/geocode_service.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';

class RideTrackingPage extends StatefulWidget {
  final String rideId;

  const RideTrackingPage({super.key, required this.rideId});

  @override
  State<RideTrackingPage> createState() => _RideTrackingPageState();
}

class _RideTrackingPageState extends State<RideTrackingPage> {
  final _docRef = FirebaseFirestore.instance.collection('rides');

  GoogleMapController? _mapController;
  Marker? _driverMarker;
  Marker? _pickupMarker;
  Marker? _destinationMarker;
  Polyline? _routePolyline;
  LatLng? _lastDriverLatLng;
  StreamSubscription<DocumentSnapshot>? _sub;

  String _status = 'pending';
  String? _driverId;
  String? _pickupLabel;
  String? _destinationLabel;

  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;

  static const LatLng _defaultPosition = LatLng(0.3476, 32.5825); // Kampala

  // For smooth animation
  Timer? _driverMoveTimer;
  int _currentRouteIndex = 0;
  List<LatLng> _driverRoutePoints = [];

  @override
  void initState() {
    super.initState();
    _listenToRide();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    _driverMoveTimer?.cancel();
    super.dispose();
  }

  void _listenToRide() {
    _sub = _docRef.doc(widget.rideId).snapshots().listen((snap) async {
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;

      setState(() {
        _status = data['status'] ?? _status;
        _driverId = data['driverId'];
      });

      // Resolve pickup
      if (_pickupLabel == null && data['pickup'] is GeoPoint) {
        final gp = data['pickup'] as GeoPoint;
        _pickupLatLng = LatLng(gp.latitude, gp.longitude);
        final label = await resolveLabel(gp.latitude, gp.longitude);
        if (mounted && label != null) {
          setState(() {
            _pickupLabel = label;
            _pickupMarker = Marker(
              markerId: const MarkerId('pickup'),
              position: _pickupLatLng!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(title: 'Pickup', snippet: label),
            );
            _updateRoute();
          });
        }
      }

      // Resolve destination
      if (_destinationLabel == null && data['destination'] is GeoPoint) {
        final gp = data['destination'] as GeoPoint;
        _destinationLatLng = LatLng(gp.latitude, gp.longitude);
        final label = await resolveLabel(gp.latitude, gp.longitude);
        if (mounted && label != null) {
          setState(() {
            _destinationLabel = label;
            _destinationMarker = Marker(
              markerId: const MarkerId('destination'),
              position: _destinationLatLng!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(title: 'Destination', snippet: label),
            );
            _updateRoute();
          });
        }
      }

      // Driver live location
      final driverLoc = data['driverLocation'];
      if (driverLoc != null &&
          driverLoc['lat'] != null &&
          driverLoc['lng'] != null) {
        final newPos = LatLng(
          (driverLoc['lat'] as num).toDouble(),
          (driverLoc['lng'] as num).toDouble(),
        );
        _animateDriverTo(newPos);
      }
    });
  }

  void _updateDriverMarker(LatLng pos) {
    _lastDriverLatLng = pos;

    final marker = Marker(
      markerId: const MarkerId('driver'),
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: 'Driver', snippet: _driverId ?? ''),
    );

    setState(() => _driverMarker = marker);

    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  // Animate driver smoothly along a new point
  void _animateDriverTo(LatLng newPos) {
    if (_lastDriverLatLng == null) {
      _updateDriverMarker(newPos);
      return;
    }

    _driverMoveTimer?.cancel();
    _driverRoutePoints = _interpolatePoints(_lastDriverLatLng!, newPos, 20);
    _currentRouteIndex = 0;

    _driverMoveTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_currentRouteIndex >= _driverRoutePoints.length) {
        timer.cancel();
        return;
      }
      _updateDriverMarker(_driverRoutePoints[_currentRouteIndex]);
      _currentRouteIndex++;
    });
  }

  // Create intermediate points between two LatLng for smooth movement
  List<LatLng> _interpolatePoints(LatLng start, LatLng end, int steps) {
    final points = <LatLng>[];
    for (int i = 1; i <= steps; i++) {
      final lat = start.latitude + (end.latitude - start.latitude) * i / steps;
      final lng =
          start.longitude + (end.longitude - start.longitude) * i / steps;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  Future<void> _updateRoute() async {
    if (_pickupLatLng == null || _destinationLatLng == null) return;

    final polylinePoints = await _getDirections(
      _pickupLatLng!,
      _destinationLatLng!,
    );

    if (polylinePoints.isNotEmpty) {
      setState(() {
        _routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: Colors.blue,
          width: 5,
        );
      });
    }
  }

  Future<List<LatLng>> _getDirections(LatLng start, LatLng end) async {
    final apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    if ((data['routes'] as List).isEmpty) return [];

    final points = <LatLng>[];
    final legs = data['routes'][0]['legs'] as List<dynamic>;
    for (var leg in legs) {
      final steps = leg['steps'] as List<dynamic>;
      for (var step in steps) {
        final polyline = step['polyline']['points'] as String;
        points.addAll(_decodePolyline(polyline));
      }
    }
    return points;
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

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_pickupMarker != null) _pickupMarker!,
      if (_destinationMarker != null) _destinationMarker!,
      if (_driverMarker != null) _driverMarker!,
    };

    final polylines = <Polyline>{if (_routePolyline != null) _routePolyline!};

    return AppScaffold(
      title: 'Ride Tracking',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: styledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Status: ${_status.replaceAll('_', ' ')}',
                          style: sectionTitleStyle(),
                        ),
                      ),
                      Text(
                        'Driver: ${_driverId ?? 'Not assigned'}',
                        style: subtleStyle(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pickup: ${_pickupLabel ?? 'Selected location'}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Destination: ${_destinationLabel ?? 'Selected location'}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _lastDriverLatLng ?? _pickupLatLng ?? _defaultPosition,
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: markers,
              polylines: polylines,
              mapType: MapType.normal,
              buildingsEnabled: true,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: true,
              myLocationEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
