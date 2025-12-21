import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'ride_service.dart';

/// Periodically reads device GPS and sends updates to the backend for a ride.
class LocationUpdater {
  final RideService _rideService;
  final String rideId;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  LocationUpdater({
    required this.rideId,
    RideService? service,
    Duration? interval,
  }) : _rideService = service ?? RideService(),
       interval = interval ?? const Duration(seconds: 4);

  Future<void> start() async {
    if (_running) return;
    _running = true;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // location services are not enabled
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // send one immediately then start timer
    await _sendOnce();
    _timer = Timer.periodic(interval, (_) => _sendOnce());
  }

  Future<void> _sendOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      await _rideService.updateDriverLocation(
        rideId: rideId,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (e) {
      // swallow errors; callers can inspect logs
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
