import 'dart:async';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/services/geocode_service.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import '../../../data/services/ride_service.dart';
import 'ride_tracking_page.dart';

class NewRidePage extends StatefulWidget {
  /// ✅ Pickup passed from dashboard (optional)
  final GeoPoint? initialPickup;

  const NewRidePage({super.key, this.initialPickup});

  @override
  State<NewRidePage> createState() => _NewRidePageState();
}

class _NewRidePageState extends State<NewRidePage> {
  final RideService _rideService = RideService();

  GeoPoint? _pickup;
  GeoPoint? _destination;

  String? _pickupLabel;
  String? _destinationLabel;

  bool _loadingPickup = false;
  bool _creatingRide = false;

  @override
  void initState() {
    super.initState();

    // Use pickup passed from dashboard if available
    if (widget.initialPickup != null) {
      _pickup = widget.initialPickup;
      _resolvePickupLabel();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptUseCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /* ===================== PICKUP ===================== */

  Future<void> _resolvePickupLabel() async {
    if (_pickup == null) return;
    final label = await resolveLabel(_pickup!.latitude, _pickup!.longitude);
    if (mounted) setState(() => _pickupLabel = label);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingPickup = true);

    // On web, navigator.geolocation requires a secure origin (https).
    // Check the current URI scheme and fall back to manual input if insecure.
    if (kIsWeb && Uri.base.scheme != 'https') {
      _showError(
        'Location on web requires HTTPS. Please enter pickup manually.',
      );
      setState(() => _loadingPickup = false);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Enable location services');
      setState(() => _loadingPickup = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showError('Location permission denied');
      setState(() => _loadingPickup = false);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _pickup = GeoPoint(pos.latitude, pos.longitude);
      _pickupLabel = await resolveLabel(pos.latitude, pos.longitude);
      setState(() {});
    } catch (_) {
      _showError('Failed to get location');
    }

    setState(() => _loadingPickup = false);
  }

  Future<void> _openPickupPicker() async {
    LatLng? selected;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: kIsWeb
              ? _buildMapPickerForPickup(selected)
              : _buildAndroidPickerForPickup(selected),
        );
      },
    );
  }

  Widget _buildMapPickerForPickup(LatLng? selected) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _pickup != null
            ? LatLng(_pickup!.latitude, _pickup!.longitude)
            : const LatLng(0.3356, 32.5686),
        zoom: 16,
      ),
      myLocationEnabled: true,
      onTap: (pos) async {
        selected = pos;
        final label = await resolveLabel(pos.latitude, pos.longitude);

        _pickup = GeoPoint(pos.latitude, pos.longitude);
        _pickupLabel = label ?? 'Selected pickup';

        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
        setState(() {});
      },
      markers: selected == null
          ? {}
          : {Marker(markerId: const MarkerId('pickup'), position: selected)},
    );
  }

  Widget _buildAndroidPickerForPickup(LatLng? selected) {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, String>> suggestions = [];
    Timer? debounce;

    return StatefulBuilder(
      builder: (context, setModalState) {
        void onChange(String value) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 300), () async {
            if (value.trim().isEmpty) return;
            final results = await placeAutocomplete(value);
            setModalState(() => suggestions = results);
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search pickup location',
                ),
                onChanged: onChange,
              ),
            ),
            Expanded(
              child: suggestions.isEmpty
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _pickup != null
                            ? LatLng(_pickup!.latitude, _pickup!.longitude)
                            : const LatLng(0.3356, 32.5686),
                        zoom: 16,
                      ),
                      myLocationEnabled: true,
                      onTap: (pos) async {
                        selected = pos;
                        final label = await resolveLabel(
                          pos.latitude,
                          pos.longitude,
                        );

                        _pickup = GeoPoint(pos.latitude, pos.longitude);
                        _pickupLabel = label ?? 'Selected pickup';

                        if (!mounted) {
                          return;
                        }
                        Navigator.of(this.context).pop();
                        setState(() {});
                      },
                      markers: selected == null
                          ? {}
                          : {
                              Marker(
                                markerId: const MarkerId('pickup'),
                                position: selected!,
                              ),
                            },
                    )
                  : ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, i) {
                        final s = suggestions[i];
                        return ListTile(
                          title: Text(s['description'] ?? ''),
                          onTap: () async {
                            final details = await placeDetailsLatLng(
                              s['place_id'] ?? '',
                            );
                            if (details == null) {
                              _showError('Failed to get place details');
                              return;
                            }

                            _pickup = GeoPoint(
                              details['lat']!,
                              details['lng']!,
                            );
                            _pickupLabel = s['description'];

                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openManualLatLngDialog({required bool forPickup}) async {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            forPickup
                ? 'Enter pickup coordinates'
                : 'Enter destination coordinates',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'Latitude'),
              ),
              TextField(
                controller: lngCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'Longitude'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Set'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      final lat = double.tryParse(latCtrl.text.trim());
      final lng = double.tryParse(lngCtrl.text.trim());
      if (lat == null || lng == null) {
        _showError('Invalid coordinates');
        return;
      }
      if (forPickup) {
        _pickup = GeoPoint(lat, lng);
        _pickupLabel = await resolveLabel(lat, lng);
      } else {
        _destination = GeoPoint(lat, lng);
        _destinationLabel = await resolveLabel(lat, lng);
      }
      if (mounted) setState(() {});
    }
  }

  /* ===================== DESTINATION ===================== */

  Future<void> _openDestinationPicker() async {
    LatLng? selected;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: kIsWeb
              ? _buildMapPicker(selected)
              : _buildAndroidPicker(selected),
        );
      },
    );
  }

  // ---------- MAP PICKER (Web + fallback) ----------
  Widget _buildMapPicker(LatLng? selected) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _pickup != null
            ? LatLng(_pickup!.latitude, _pickup!.longitude)
            : const LatLng(0.3356, 32.5686),
        zoom: 16,
      ),
      myLocationEnabled: true,
      onTap: (pos) async {
        selected = pos;
        final label = await resolveLabel(pos.latitude, pos.longitude);

        _destination = GeoPoint(pos.latitude, pos.longitude);
        _destinationLabel = label ?? 'Selected location';

        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
        setState(() {});
      },
      markers: selected == null
          ? {}
          : {Marker(markerId: const MarkerId('dest'), position: selected)},
    );
  }

  // ---------- ANDROID PICKER (Search + Map) ----------
  Widget _buildAndroidPicker(LatLng? selected) {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, String>> suggestions = [];
    Timer? debounce;

    return StatefulBuilder(
      builder: (context, setModalState) {
        void onChange(String value) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 300), () async {
            if (value.trim().isEmpty) return;
            final results = await placeAutocomplete(value);
            setModalState(() => suggestions = results);
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search destination',
                ),
                onChanged: onChange,
              ),
            ),
            Expanded(
              child: suggestions.isEmpty
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _pickup != null
                            ? LatLng(_pickup!.latitude, _pickup!.longitude)
                            : const LatLng(0.3356, 32.5686),
                        zoom: 16,
                      ),
                      myLocationEnabled: true,
                      onTap: (pos) async {
                        selected = pos;
                        final label = await resolveLabel(
                          pos.latitude,
                          pos.longitude,
                        );

                        _destination = GeoPoint(pos.latitude, pos.longitude);
                        _destinationLabel = label ?? 'Selected location';

                        if (!mounted) {
                          return;
                        }
                        Navigator.of(this.context).pop();
                        setState(() {});
                      },
                      markers: selected == null
                          ? {}
                          : {
                              Marker(
                                markerId: const MarkerId('dest'),
                                position: selected!,
                              ),
                            },
                    )
                  : ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, i) {
                        final s = suggestions[i];
                        return ListTile(
                          title: Text(s['description'] ?? ''),
                          onTap: () async {
                            final details = await placeDetailsLatLng(
                              s['place_id'] ?? '',
                            );
                            if (details == null) {
                              _showError('Failed to get place details');
                              return;
                            }

                            _destination = GeoPoint(
                              details['lat']!,
                              details['lng']!,
                            );
                            _destinationLabel = s['description'];

                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /* ===================== CREATE RIDE ===================== */

  Future<void> _requestRide() async {
    if (_pickup == null) {
      _showError('Pickup not set');
      return;
    }
    if (_destination == null) {
      _showError('Select destination');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please sign in');
      return;
    }

    setState(() => _creatingRide = true);

    final rideId = await _rideService.createRide(
      studentId: user.uid,
      pickup: _pickup!,
      destination: _destination!,
      specialNeeds: {},
    );

    setState(() => _creatingRide = false);

    if (!mounted) return;
    // Use addPostFrameCallback to avoid using BuildContext across async gaps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideTrackingPage(rideId: rideId)),
      );
    });
  }

  Future<void> _promptUseCurrentLocation() async {
    if (!mounted) return;
    final use = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Use current location?'),
          content: const Text(
            'Allow the app to access your location to auto-fill pickup coordinates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (use == true) {
      await _getCurrentLocation();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ===================== UI ===================== */

  @override
  Widget build(BuildContext context) {
    return
    // Use shared AppScaffold for consistent design across pages
    // (keeps app bar gradient, rounded bottom and background color).
    // The actual page content remains the same.
    /**
         * NOTE: We import AppScaffold lazily to avoid import cycles. Add the
         * import at the top of the file: import '../../shared/app_scaffold.dart';
         */
    AppScaffold(
      title: 'Request Ride',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Pickup', style: sectionTitleStyle()),
            const SizedBox(height: 8),
            styledCard(
              child: ListTile(
                leading: const Icon(Icons.my_location, color: kPrimaryBlue),
                title: Text(
                  _pickupLabel ?? 'Not set',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: _loadingPickup
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _getCurrentLocation,
                            style: primaryButtonStyle(),
                            child: const Text('SET'),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _openPickupPicker,
                            style: primaryButtonStyle(),
                            child: const Text('PICK'),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () =>
                                _openManualLatLngDialog(forPickup: true),
                            style: primaryButtonStyle(),
                            child: const Text('MANUAL'),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Destination', style: sectionTitleStyle()),
            const SizedBox(height: 8),
            styledCard(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: kPrimaryTeal),
                title: Text(
                  _destinationLabel ?? 'Search destination',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _openDestinationPicker,
                      style: primaryButtonStyle(),
                      child: const Text('SEARCH'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () =>
                          _openManualLatLngDialog(forPickup: false),
                      style: primaryButtonStyle(),
                      child: const Text('MANUAL'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _creatingRide ? null : _requestRide,
              style: primaryButtonStyle(),
              child: _creatingRide
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Request Ride'),
            ),
          ],
        ),
      ),
    );
  }
}
