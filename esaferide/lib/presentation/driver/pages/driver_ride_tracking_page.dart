import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/chat_page.dart';
import '../../../data/services/chat_service.dart';

import '../../../data/services/geocode_service.dart';
import 'package:esaferide/utils/platform_api_key.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import '../../../data/services/ride_service.dart';

class DriverRideTrackingPage extends StatefulWidget {
  final String rideId;
  final String? chatId;

  const DriverRideTrackingPage({super.key, required this.rideId, this.chatId});

  @override
  State<DriverRideTrackingPage> createState() => _DriverRideTrackingPageState();
}

class _DriverRideTrackingPageState extends State<DriverRideTrackingPage> {
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

  String _status = 'pending';
  String? _driverId;
  String? _driverName;
  String? _pickupLabel;
  String? _destinationLabel;
  String? _studentId;
  String? _studentName;
  String? _currentUserId;

  bool get _isCurrentDriver =>
      _currentUserId != null &&
      _driverId != null &&
      _currentUserId == _driverId;

  // ETA / distance info
  int? _routeDurationSeconds;
  int? _driverEtaSeconds;
  int? _routeDistanceMeters;
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
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _listenToRide();
  }

  Future<void> _loadApiKey() async {
    _googleMapsApiKey = await PlatformApiKey.getGoogleMapsApiKey();
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

      if (_driverId != null && _driverId!.isNotEmpty) {
        _loadDriverName(_driverId!);
      }

      // Pickup marker
      if (data['pickup'] is GeoPoint) {
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
          });
          _updateRoute(); // Update route polyline automatically
        }
      }

      // student id/name
      if (data['studentId'] != null) {
        final sid = data['studentId'] as String?;
        if (sid != null) {
          _studentId = sid;
          final sdoc = await FirebaseFirestore.instance
              .collection('students')
              .doc(sid)
              .get();
          if (sdoc.exists && sdoc.data() != null) {
            _studentName =
                (sdoc.data() as Map<String, dynamic>)['fullName'] as String? ??
                sid;
          }
        }
      }

      // Destination marker
      if (data['destination'] is GeoPoint) {
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
          });
          _updateRoute();
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
        if (_lastDriverRouteFetch == null ||
            DateTime.now().difference(_lastDriverRouteFetch!) >=
                _driverRouteThrottle) {
          _lastDriverRouteFetch = DateTime.now();
          _updateDriverRoute(newPos);
        }
        _fitMapToIncludeDriver(newPos);
      }
    });
  }

  Future<void> _loadDriverName(String driverId) async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (mounted) {
        setState(() {
          _driverName = data['fullName'] ?? data['name'];
        });
      }
    }
  }

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

  void _updateDriverMarker(LatLng pos) {
    _lastDriverLatLng = pos;
    setState(() {
      _driverMarker = Marker(
        markerId: const MarkerId('driver'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: 'Driver',
          snippet: _driverName ?? _driverId ?? '',
        ),
      );
    });
  }

  Future<void> _updateRoute() async {
    if (_pickupLatLng == null || _destinationLatLng == null) return;
    final res = await _getDirectionsWithMeta(
      _pickupLatLng!,
      _destinationLatLng!,
    );
    final points =
        (res['points'] as List<LatLng>?) ??
        [_pickupLatLng!, _destinationLatLng!];
    setState(() {
      _routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue,
        width: 5,
      );
      _routeDurationSeconds = (res['duration'] as int?) ?? 0;
      _routeDistanceMeters = (res['distance'] as int?) ?? 0;
    });
    _fitMapToRoute();
  }

  Future<void> _updateDriverRoute(LatLng driverPos) async {
    if (_pickupLatLng == null) return;
    final res = await _getDirectionsWithMeta(driverPos, _pickupLatLng!);
    final points =
        (res['points'] as List<LatLng>?) ?? [driverPos, _pickupLatLng!];
    setState(() {
      _driverToPickupPolyline = Polyline(
        polylineId: const PolylineId('driver_to_pickup'),
        points: points,
        color: Colors.orange,
        width: 4,
        patterns: [PatternItem.dash(10), PatternItem.gap(6)],
      );
      _driverEtaSeconds = (res['duration'] as int?);
      _driverDistanceToPickupMeters =
          (res['distance'] as int?) ??
          _haversineDistance(driverPos, _pickupLatLng!).round();
    });
  }

  Future<Map<String, dynamic>> _getDirectionsWithMeta(
    LatLng start,
    LatLng end,
  ) async {
    Map<String, dynamic> data;
    final apiKey = _googleMapsApiKey ?? 'YOUR_FALLBACK_API_KEY';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&alternatives=false&key=$apiKey';
    final response = await http.get(Uri.parse(url));
    data = json.decode(response.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? [];
    if (routes.isEmpty) {
      return {'points': <LatLng>[], 'duration': 0, 'distance': 0};
    }

    final overview = routes[0]['overview_polyline']?['points'] as String?;
    final points = overview != null ? _decodePolyline(overview) : [start, end];
    int duration = 0, distance = 0;
    final legs = routes[0]['legs'] as List<dynamic>? ?? [];
    for (var leg in legs) {
      duration += (leg['duration']?['value'] as int?) ?? 0;
      distance += (leg['distance']?['value'] as int?) ?? 0;
    }
    return {'points': points, 'duration': duration, 'distance': distance};
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
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

  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final sa =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(sa), sqrt(1 - sa));
    return R * c;
  }

  void _fitMapToIncludeDriver(LatLng driverPos) {
    final points = <LatLng>[driverPos];
    if (_pickupLatLng != null) points.add(_pickupLatLng!);
    if (_destinationLatLng != null) points.add(_destinationLatLng!);
    if (points.isEmpty) return;
    double minLat = points.first.latitude,
        maxLat = points.first.latitude,
        minLng = points.first.longitude,
        maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  void _fitMapToRoute() {
    final points = <LatLng>[];
    if (_routePolyline != null) points.addAll(_routePolyline!.points);
    if (_pickupLatLng != null) points.add(_pickupLatLng!);
    if (_destinationLatLng != null) points.add(_destinationLatLng!);
    if (points.isEmpty) return;
    double minLat = points.first.latitude,
        maxLat = points.first.latitude,
        minLng = points.first.longitude,
        maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    if (hrs > 0) return '${hrs}h ${remMins}m';
    return '${mins}m';
  }

  Future<void> _markArrived() async {
    if (widget.rideId.isEmpty) return;
    await RideService().updateStatus(rideId: widget.rideId, status: 'arrived');
    if (!mounted) return;
    setState(() {
      _status = 'arrived';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marked arrived')));
  }

  Future<void> _markTripStarted() async {
    if (widget.rideId.isEmpty) return;
    await RideService().updateStatus(
      rideId: widget.rideId,
      status: 'trip_started',
    );
    if (!mounted) return;
    setState(() {
      _status = 'trip_started';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trip started')));
  }

  Future<void> _markCompleted() async {
    if (widget.rideId.isEmpty || _currentUserId == null) return;
    final duration = _routeDurationSeconds ?? 0;
    final fare = 5.0 + ((duration / 60.0) * 0.5);
    final ok = await RideService().completeTrip(
      rideId: widget.rideId,
      driverId: _currentUserId!,
      durationSeconds: duration,
      fare: double.parse(fare.toStringAsFixed(2)),
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _status = 'completed';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip completed')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to complete trip')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_pickupMarker != null) _pickupMarker!,
      if (_destinationMarker != null) _destinationMarker!,
      if (_driverMarker != null) _driverMarker!,
    };
    final polylines = <Polyline>{
      if (_routePolyline != null) _routePolyline!,
      if (_driverToPickupPolyline != null) _driverToPickupPolyline!,
    };

    return AppScaffold(
      title: 'Driver Map',
      actions: [
        IconButton(
          tooltip: 'Chat with student',
          onPressed: () async {
            if ((_studentId == null && widget.chatId == null) ||
                _currentUserId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No student assigned yet')),
              );
              return;
            }

            final navigator = Navigator.of(context);

            final a = _currentUserId!;
            final b = _studentId ?? '';
            String chatId;
            if (widget.chatId != null) {
              chatId = widget.chatId!;
            } else {
              chatId = ChatService.chatIdFor(a, b);
              await ChatService().createChatIfNotExists(a: a, b: b);
            }

            if (!mounted) return;
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  chatId: chatId,
                  otherUserId: b,
                  otherUserName: _studentName,
                ),
              ),
            );
          },
          icon: const Icon(Icons.chat_bubble, color: Colors.white),
        ),
      ],
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_driverEtaSeconds != null)
                        Chip(
                          avatar: const Icon(Icons.directions_bike, size: 20),
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
                      const SizedBox(width: 8),
                      if (_routeDistanceMeters != null)
                        Chip(
                          avatar: const Icon(Icons.timeline, size: 20),
                          label: Text('Distance: $_routeDistanceMeters m'),
                        ),
                      const SizedBox(width: 8),
                      if (_driverDistanceToPickupMeters != null)
                        Chip(
                          avatar: const Icon(Icons.pin_drop, size: 20),
                          label: Text(
                            'Driver to pickup: $_driverDistanceToPickupMeters m',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isCurrentDriver) ...[
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed:
                              (_status == 'accepted' || _status == 'on_the_way')
                              ? _markArrived
                              : null,
                          child: const Text('Arrived'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              (_status == 'arrived' ||
                                  _status == 'accepted' ||
                                  _status == 'on_the_way')
                              ? _markTripStarted
                              : null,
                          child: const Text('Start Trip'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: (_status == 'trip_started')
                              ? _markCompleted
                              : null,
                          child: const Text('Complete'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target:
                        _lastDriverLatLng ?? _pickupLatLng ?? _defaultPosition,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: markers,
                  polylines: polylines,
                  mapType: MapType.normal,
                  buildingsEnabled: true,
                  zoomControlsEnabled: true,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: false,
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'tracking_chat',
                    onPressed: () async {
                      if ((_studentId == null && widget.chatId == null) ||
                          _currentUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No student assigned yet'),
                          ),
                        );
                        return;
                      }

                      // ensure chat doc exists (create if needed) so unreadCounts etc. are present
                      final a = _currentUserId!;
                      final b = _studentId ?? '';
                      String chatId;
                      final navigator = Navigator.of(context);
                      if (widget.chatId != null) {
                        chatId = widget.chatId!;
                      } else {
                        chatId = ChatService.chatIdFor(a, b);
                        await ChatService().createChatIfNotExists(a: a, b: b);
                      }

                      if (!mounted) return;
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            chatId: chatId,
                            otherUserId: b,
                            otherUserName: _studentName,
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.chat),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
