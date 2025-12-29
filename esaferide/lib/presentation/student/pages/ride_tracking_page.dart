import 'dart:async';
import 'dart:convert';
import 'dart:math';
// 'dart:math' was unused and removed to satisfy lints

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../data/services/geocode_service.dart';
import 'package:esaferide/utils/platform_api_key.dart';
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
  Polyline? _driverToPickupPolyline;
  LatLng? _lastDriverLatLng;
  StreamSubscription<DocumentSnapshot>? _sub;
  DateTime? _lastDriverRouteFetch;
  static const Duration _driverRouteThrottle = Duration(seconds: 8);

  String? _googleMapsApiKey;
  String? _directionsFunctionUrl;

  String _status = 'pending';
  String? _driverId;
  String? _pickupLabel;
  String? _destinationLabel;

  // ETA / distance info
  int? _routeDurationSeconds;
  int? _routeDistanceMeters;
  int? _driverEtaSeconds;
  int? _driverDistanceToPickupMeters;

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
    _loadApiKey();
    _listenToRide();
  }

  Future<void> _loadApiKey() async {
    try {
      _googleMapsApiKey = await PlatformApiKey.getGoogleMapsApiKey();
      _directionsFunctionUrl = await PlatformApiKey.getDirectionsFunctionUrl();
      debugPrint(
        'Loaded Google Maps API key: ${_googleMapsApiKey != null ? "(present)" : "(missing)"}; directionsFunctionUrl: ${_directionsFunctionUrl != null ? "(present)" : "(missing)"}',
      );
    } catch (e) {
      debugPrint('Error loading Google Maps API key: $e');
      _googleMapsApiKey = null;
    }
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
        debugPrint('RideTracking: received driverLocation $newPos');
        _animateDriverTo(newPos);
        // Also update the driver->pickup route so rider can see where driver is heading
        // throttle frequent directions calls
        if (_lastDriverRouteFetch == null ||
            DateTime.now().difference(_lastDriverRouteFetch!) >=
                _driverRouteThrottle) {
          _lastDriverRouteFetch = DateTime.now();
          _updateDriverRoute(newPos);
        }
        // ensure driver is visible on map
        _fitMapToIncludeDriver(newPos);
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

    final res = await _getDirectionsWithMeta(
      _pickupLatLng!,
      _destinationLatLng!,
    );
    final polylinePoints = (res['points'] as List<LatLng>?) ?? <LatLng>[];
    final duration = (res['duration'] as int?) ?? 0;
    final distance = (res['distance'] as int?) ?? 0;

    final points = polylinePoints.isNotEmpty
        ? polylinePoints
        : [_pickupLatLng!, _destinationLatLng!];

    setState(() {
      _routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue,
        width: 5,
      );
      _routeDurationSeconds = duration > 0 ? duration : null;
      _routeDistanceMeters = distance > 0
          ? distance
          : (_pickupLatLng != null && _destinationLatLng != null
                ? _haversineDistance(
                    _pickupLatLng!,
                    _destinationLatLng!,
                  ).round()
                : null);
    });
  }

  /// A helper that returns decoded polyline points together with duration and distance (in seconds/meters).
  Future<Map<String, dynamic>> _getDirectionsWithMeta(
    LatLng start,
    LatLng end,
  ) async {
    Map<String, dynamic> data;

    if (_directionsFunctionUrl != null && _directionsFunctionUrl!.isNotEmpty) {
      final funcUrl =
          '${_directionsFunctionUrl!}?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}';
      debugPrint('Calling directions via Cloud Function: $funcUrl');
      final response = await http.get(Uri.parse(funcUrl));
      if (response.statusCode != 200) {
        debugPrint('Directions function error: HTTP ${response.statusCode}');
        debugPrint('Body: ${response.body}');
        return {'points': <LatLng>[], 'duration': 0, 'distance': 0};
      }
      data = json.decode(response.body) as Map<String, dynamic>;
    } else {
      final apiKey = _googleMapsApiKey?.isNotEmpty == true
          ? _googleMapsApiKey!
          : 'AIzaSyApNrcg8oYtgww7uJnMaMXYz7lgyvX5aNc';
      debugPrint(
        'Using Google Maps API key: ${_googleMapsApiKey != null ? "(runtime)" : "(embedded fallback)"}',
      );

      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&alternatives=false&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('Directions API error: HTTP ${response.statusCode}');
        debugPrint('Body: ${response.body}');
        return {'points': <LatLng>[], 'duration': 0, 'distance': 0};
      }
      data = json.decode(response.body) as Map<String, dynamic>;
    }

    final routes = (data['routes'] as List?) ?? [];
    if (routes.isEmpty) {
      debugPrint(
        'Directions API returned no routes. Body: ${json.encode(data)}',
      );
      return {'points': <LatLng>[], 'duration': 0, 'distance': 0};
    }

    final firstRoute = routes[0] as Map<String, dynamic>;
    final overview = firstRoute['overview_polyline'];
    final points = <LatLng>[];
    if (overview != null &&
        overview is Map<String, dynamic> &&
        overview['points'] is String) {
      points.addAll(_decodePolyline(overview['points'] as String));
    } else {
      int totalDuration = 0;
      int totalDistance = 0;
      final legs = firstRoute['legs'] as List<dynamic>? ?? [];
      for (var leg in legs) {
        totalDuration += (leg['duration']?['value'] as int?) ?? 0;
        totalDistance += (leg['distance']?['value'] as int?) ?? 0;
        final steps = leg['steps'] as List<dynamic>? ?? [];
        for (var step in steps) {
          final polyline = step['polyline']?['points'] as String?;
          if (polyline != null) points.addAll(_decodePolyline(polyline));
        }
      }
      return {
        'points': points,
        'duration': totalDuration,
        'distance': totalDistance,
      };
    }

    int totalDuration = 0;
    int totalDistance = 0;
    final legs = firstRoute['legs'] as List<dynamic>? ?? [];
    for (var leg in legs) {
      totalDuration += (leg['duration']?['value'] as int?) ?? 0;
      totalDistance += (leg['distance']?['value'] as int?) ?? 0;
    }

    debugPrint(
      'Directions fetched: points=${points.length}, duration=$totalDuration, distance=$totalDistance',
    );

    return {
      'points': points,
      'duration': totalDuration,
      'distance': totalDistance,
    };
  }

  // Fallback simple haversine distance (meters)
  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000; // meters
    final lat1 = a.latitude * (3.141592653589793 / 180);
    final lat2 = b.latitude * (3.141592653589793 / 180);
    final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180);
    final dLon = (b.longitude - a.longitude) * (3.141592653589793 / 180);
    final sa =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1) * cos(lat2) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(sa), sqrt(1 - sa));
    return R * c;
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
    if (_driverToPickupPolyline != null) {
      polylines.add(_driverToPickupPolyline!);
    }

    return AppScaffold(
      title: 'Ride Tracking',
      child: Stack(
        children: [
          Column(
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
                          const SizedBox(width: 8),
                          // Removed the duplicate header "Show route" button. Use the floating
                          // Route button (bottom-right) to show the route between pickup and
                          // destination. That button only appears when both locations are set.
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
                      const SizedBox(height: 8),
                      // ETA badges
                      Row(
                        children: [
                          if (_driverEtaSeconds != null)
                            Chip(
                              avatar: const Icon(
                                Icons.directions_bike,
                                size: 20,
                              ),
                              label: Text(
                                'Driver ETA: ${_formatSeconds(_driverEtaSeconds!)}',
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (_routeDurationSeconds != null)
                            Chip(
                              avatar: const Icon(Icons.access_time, size: 20),
                              label: Text(
                                'Trip: ${_formatSeconds(_routeDurationSeconds!)}',
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
                    target:
                        _lastDriverLatLng ?? _pickupLatLng ?? _defaultPosition,
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
          // Floating route button overlayed on the map — show only when pickup & destination exist
          if (_pickupLatLng != null && _destinationLatLng != null)
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  await _updateRoute();
                  _fitMapToRoute();
                },
                label: const Text('Show route'),
                icon: const Icon(Icons.alt_route),
              ),
            ),
        ],
      ),
    );
  }

  /// Update a separate polyline that shows the driver's route to the pickup point.
  Future<void> _updateDriverRoute(LatLng driverPos) async {
    if (_pickupLatLng == null) return;

    try {
      final res = await _getDirectionsWithMeta(driverPos, _pickupLatLng!);
      final points = (res['points'] as List<LatLng>?) ?? <LatLng>[];
      final duration = (res['duration'] as int?) ?? 0;
      final distance = (res['distance'] as int?) ?? 0;

      final used = points.isNotEmpty ? points : [driverPos, _pickupLatLng!];
      setState(() {
        _driverToPickupPolyline = Polyline(
          polylineId: const PolylineId('driver_to_pickup'),
          points: used,
          color: Colors.orange,
          width: 4,
          patterns: [PatternItem.dash(10), PatternItem.gap(6)],
        );
        if (duration > 0) {
          _driverEtaSeconds = duration;
        } else {
          _driverEtaSeconds = null;
        }

        if (distance > 0) {
          _driverDistanceToPickupMeters = distance;
        } else {
          // fallback to haversine distance if directions did not return metrics
          _driverDistanceToPickupMeters = _haversineDistance(
            driverPos,
            _pickupLatLng!,
          ).round();
        }
      });
    } catch (e) {
      // ignore errors from directions fetch; route is optional
    }
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    if (hrs > 0) return '${hrs}h ${remMins}m';
    return '${mins}m';
  }

  void _fitMapToIncludeDriver(LatLng driverPos) {
    // compute bounds including driver, pickup and destination
    final points = <LatLng>[];
    points.add(driverPos);
    if (_pickupLatLng != null) points.add(_pickupLatLng!);
    if (_destinationLatLng != null) points.add(_destinationLatLng!);
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final padding = 80.0;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (_) {
      // might throw if map not ready; ignore
    }
  }

  void _fitMapToRoute() {
    // Fit the map camera to the route polyline or to pickup/destination markers
    final points = <LatLng>[];
    if (_routePolyline != null) points.addAll(_routePolyline!.points);
    if (_pickupLatLng != null) points.add(_pickupLatLng!);
    if (_destinationLatLng != null) points.add(_destinationLatLng!);
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final padding = 50.0;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }
}
