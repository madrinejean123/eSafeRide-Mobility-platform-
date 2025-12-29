import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';
import 'package:esaferide/config/maps_config.dart';

// Simple LatLng tween for interpolation (if needed elsewhere)
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
    : super(begin: begin, end: end);
  @override
  LatLng lerp(double t) => LatLng(
    begin!.latitude + (end!.latitude - begin!.latitude) * t,
    begin!.longitude + (end!.longitude - begin!.longitude) * t,
  );
}

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
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;

  // Timer-based per-ride animation state
  final Map<String, Timer?> _driverMoveTimers = {};
  final Map<String, List<LatLng>> _driverRoutePoints = {};
  final Map<String, int> _driverRouteIndex = {};
  final Map<String, LatLng> _currentPositions = {};

  static const CameraPosition _initialCamera = CameraPosition(
    // Default to the same general Kampala / Makerere area used by the
    // student RideTrackingPage so admins see the same local area by default.
    target: LatLng(0.3476, 32.5825),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      // Use the newer BitmapDescriptor.asset API which takes an ImageConfiguration
      // and returns a Future that resolves to the platform-specific asset bitmap.
      final cfg = ImageConfiguration(size: const Size(48, 48));
      _driverIcon = await BitmapDescriptor.asset(
        cfg,
        'assets/images/shuttle.png',
      );
      _pickupIcon = await BitmapDescriptor.asset(
        cfg,
        'assets/avatar_placeholder.png',
      );
      _destIcon = await BitmapDescriptor.asset(
        cfg,
        'assets/images/safelogo.png',
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error loading marker icons: $e');
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    for (final t in _driverMoveTimers.values) {
      t?.cancel();
    }
    super.dispose();
  }

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

  void _animateDriverToRide(String rideId, LatLng newPos) {
    final prev = _currentPositions[rideId];
    if (prev == null) {
      setState(() {
        final key = '$rideId-driver';
        _markers[key] = Marker(
          markerId: MarkerId(key),
          position: newPos,
          icon:
              _driverIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Driver • Ride $rideId'),
        );
        _currentPositions[rideId] = newPos;
      });
      return;
    }
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
          } else {
            _markers[key] = Marker(
              markerId: MarkerId(key),
              position: pos,
              icon:
                  _driverIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
            );
          }
        });
      },
    );
  }

  Future<Polyline?> _fetchRoutePolyline(String id, LatLng a, LatLng b) async {
    final key = googleDirectionsApiKey;
    if (key.isEmpty) {
      return Polyline(
        polylineId: PolylineId(id),
        points: [a, b],
        color: Colors.blueAccent.withAlpha((0.7 * 255).round()),
        width: 4,
      );
    }
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${a.latitude},${a.longitude}&destination=${b.latitude},${b.longitude}&key=$key',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        return Polyline(
          polylineId: PolylineId(id),
          points: [a, b],
          color: Colors.blueAccent.withAlpha((0.7 * 255).round()),
          width: 4,
        );
      }
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return Polyline(
          polylineId: PolylineId(id),
          points: [a, b],
          color: Colors.blueAccent.withAlpha((0.7 * 255).round()),
          width: 4,
        );
      }
      final overview = routes.first['overview_polyline']?['points'] as String?;
      if (overview == null || overview.isEmpty) {
        return Polyline(
          polylineId: PolylineId(id),
          points: [a, b],
          color: Colors.blueAccent.withAlpha((0.7 * 255).round()),
          width: 4,
        );
      }
      final pts = _decodePolyline(overview);
      return Polyline(
        polylineId: PolylineId(id),
        points: pts,
        color: Colors.blueAccent.withAlpha((0.8 * 255).round()),
        width: 5,
      );
    } catch (e) {
      debugPrint('Directions fetch error: $e');
      return Polyline(
        polylineId: PolylineId(id),
        points: [a, b],
        color: Colors.blueAccent.withAlpha((0.7 * 255).round()),
        width: 4,
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      final double latitude = lat / 1e5;
      final double longitude = lng / 1e5;
      poly.add(LatLng(latitude, longitude));
    }
    return poly;
  }

  void _updateMarkersFromDocs(List<QueryDocumentSnapshot> docs) {
    final next = <String, Marker>{};
    final nextPolylines = <String, Polyline>{};
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['driverLocation'] != null) {
        final lat = (data['driverLocation']['lat'] as num?)?.toDouble();
        final lng = (data['driverLocation']['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final newPos = LatLng(lat, lng);
          final prev = _currentPositions[d.id];
          if (prev != null) _animateDriverToRide(d.id, newPos);
          _currentPositions[d.id] = newPos;
          next['${d.id}-driver'] = Marker(
            markerId: MarkerId('${d.id}-driver'),
            position: newPos,
            infoWindow: InfoWindow(
              title: 'Driver • Ride ${d.id}',
              snippet: data['studentName'] ?? data['studentId'] ?? '',
              onTap: () => _showRideDetails(d.id, data),
            ),
            icon:
                _driverIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        }
      }
      final gp = data['pickup'] as GeoPoint?;
      if (gp != null) {
        next['${d.id}-pickup'] = Marker(
          markerId: MarkerId('${d.id}-pickup'),
          position: LatLng(gp.latitude, gp.longitude),
          infoWindow: InfoWindow(
            title: 'Pickup • Ride ${d.id}',
            snippet: data['studentName'] ?? data['studentId'] ?? '',
            onTap: () => _showRideDetails(d.id, data),
          ),
          icon:
              _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
      }
      final dest = data['destination'] as GeoPoint?;
      if (dest != null) {
        next['${d.id}-dest'] = Marker(
          markerId: MarkerId('${d.id}-dest'),
          position: LatLng(dest.latitude, dest.longitude),
          infoWindow: InfoWindow(
            title: 'Destination • Ride ${d.id}',
            snippet: data['studentName'] ?? data['studentId'] ?? '',
            onTap: () => _showRideDetails(d.id, data),
          ),
          icon:
              _destIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }
      if (gp != null && dest != null) {
        final a = LatLng(gp.latitude, gp.longitude);
        final b = LatLng(dest.latitude, dest.longitude);
        nextPolylines[d.id] = Polyline(
          polylineId: PolylineId(d.id),
          points: [a, b],
          color: Colors.blueAccent.withAlpha((0.7 * 255).round()),
          width: 4,
        );
        _fetchRoutePolyline(d.id, a, b)
            .then((poly) {
              if (poly != null) setState(() => _polylines[d.id] = poly);
            })
            .catchError((e) {
              debugPrint('route fetch error: $e');
            });
      }
    }
    setState(() {
      _markers
        ..clear()
        ..addAll(next);
      _polylines
        ..clear()
        ..addAll(nextPolylines);
    });
  }

  Future<void> _showRideDetails(String id, Map<String, dynamic> data) async {
    Map<String, dynamic>? studentData;
    try {
      final studentId = data['studentId'] as String?;
      if (studentId != null && studentId.isNotEmpty) {
        final sdoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();
        if (sdoc.exists && sdoc.data() != null) {
          studentData = sdoc.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error fetching student profile: $e');
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ride $id', style: sectionTitleStyle()),
                const SizedBox(height: 6),
                Text(
                  'Student: ${studentData?['fullName'] ?? data['studentName'] ?? data['studentId'] ?? '—'}',
                ),
                const SizedBox(height: 6),
                Text('Status: ${data['status'] ?? '—'}'),
                const SizedBox(height: 6),
                if (data['driverId'] != null)
                  Text('Driver: ${data['driverId']}'),
                const SizedBox(height: 12),
                if (studentData != null) ...[
                  if (studentData['photo'] != null) ...[
                    const Text('Photo'),
                    const SizedBox(height: 6),
                    Image.network(
                      studentData['photo'],
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Name: ${studentData['fullName'] ?? studentData['name'] ?? '—'}',
                  ),
                  const SizedBox(height: 6),
                  Text('Reg#: ${studentData['regNumber'] ?? '—'}'),
                  const SizedBox(height: 6),
                  Text(
                    'Course: ${studentData['course'] ?? studentData['class'] ?? '—'}',
                  ),
                  const SizedBox(height: 6),
                  Text('Year: ${studentData['year'] ?? '—'}'),
                  const SizedBox(height: 6),
                  Text('Phone: ${studentData['phone'] ?? '—'}'),
                  const SizedBox(height: 6),
                  if (studentData['accessibility'] != null) ...[
                    const Text('Accessibility Needs'),
                    const SizedBox(height: 6),
                    Text(studentData['accessibility'].toString()),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 12),
                  const Text('Emergency Contact'),
                  const SizedBox(height: 6),
                  Text('Name: ${studentData['emergencyName'] ?? '—'}'),
                  const SizedBox(height: 4),
                  Text('Phone: ${studentData['emergencyPhone'] ?? '—'}'),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final m = _markers[id];
                        if (m != null && _mapController != null) {
                          await _mapController!.animateCamera(
                            CameraUpdate.newLatLng(m.position),
                          );
                        }
                      },
                      child: const Text('Center'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SizedBox.shrink(),
                          ),
                        );
                      },
                      child: const Text('Open Rides'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Live Map',
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _initialCamera,
                    onMapCreated: (c) {
                      _mapController = c;
                      debugPrint('AdminLiveMap: onMapCreated - controller set');
                      if (mounted) setState(() {});
                    },
                    onCameraIdle: () => debugPrint('AdminLiveMap: camera idle'),
                    markers: Set<Marker>.of(_markers.values),
                    polylines: Set<Polyline>.of(_polylines.values),
                    // Match the student RideTrackingPage map settings so admins
                    // see the same map behavior and controls.
                    mapType: MapType.normal,
                    buildingsEnabled: true,
                    zoomControlsEnabled: true,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: true,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.5 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _mapController == null
                            ? 'Map initializing…'
                            : 'Map ready',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: StreamBuilder<QuerySnapshot>(
                stream: _rideCol
                    .where(
                      'status',
                      whereIn: ['accepted', 'on_the_way', 'active'],
                    )
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateMarkersFromDocs(docs);
                  });
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No active rides',
                        style: sectionTitleStyle(),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data() as Map<String, dynamic>;
                      final gp = data['pickup'] as GeoPoint?;
                      final pos = data['driverLocation'] != null
                          ? LatLng(
                              (data['driverLocation']['lat'] as num).toDouble(),
                              (data['driverLocation']['lng'] as num).toDouble(),
                            )
                          : (gp != null
                                ? LatLng(gp.latitude, gp.longitude)
                                : null);
                      return ListTile(
                        title: Text(
                          'Ride ${d.id} • ${data['studentName'] ?? ''}',
                        ),
                        subtitle: Text('Status: ${data['status'] ?? '—'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.location_searching),
                          onPressed: () {
                            if (pos != null && _mapController != null) {
                              _mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(pos, 15),
                              );
                            }
                          },
                        ),
                        onTap: () => _showRideDetails(d.id, data),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
