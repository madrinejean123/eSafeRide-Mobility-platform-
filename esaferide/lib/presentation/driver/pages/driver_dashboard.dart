import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/config/routes.dart';
import 'package:esaferide/presentation/auth/login_page.dart';
import 'package:esaferide/presentation/driver/pages/driver_profile.dart';
import '../../../data/services/ride_service.dart';
import '../../../data/services/location_updater.dart';
import '../../../data/services/geocode_service_io.dart';
import 'available_rides_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with SingleTickerProviderStateMixin {
  late final String uid;
  bool _isDark = false;
  late final AnimationController _pulseController;
  Timer? _tripTimer;
  Duration _currentTripTime = const Duration(minutes: 12);

  // Overlay & profile
  bool _showDriverProfile = false;

  // Driver info
  String _driverName = '';
  String _driverPhotoUrl = '';

  // Ride notifications
  List<QueryDocumentSnapshot> _pendingRides = [];
  StreamSubscription<QuerySnapshot>? _ridesSub;
  LocationUpdater? _updater;
  final Map<String, String> _rideAddressCache = {};

  // Form controllers
  final TextEditingController fullNameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController govIdCtrl = TextEditingController();
  final TextEditingController licenseNoCtrl = TextEditingController();
  final TextEditingController regNoCtrl = TextEditingController();
  final TextEditingController makeModelCtrl = TextEditingController();
  final TextEditingController yearCtrl = TextEditingController();
  final TextEditingController emergencyNameCtrl = TextEditingController();
  final TextEditingController emergencyPhoneCtrl = TextEditingController();

  bool _showAlert = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });
      return;
    }

    uid = user.uid.trim();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startTripCountdown();
    _checkProfileCompletion();
    _listenToPendingRides();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tripTimer?.cancel();
    _ridesSub?.cancel();
    _updater?.stop();
    super.dispose();
  }

  // -------------------- PROFILE LOGIC --------------------
  Future<void> _checkProfileCompletion() async {
    if (uid.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) {
      setState(() => _showDriverProfile = true);
    } else {
      final data = doc.data()!;
      fullNameCtrl.text = data['fullName'] ?? '';
      phoneCtrl.text = data['phone'] ?? '';
      emailCtrl.text = data['email'] ?? '';
      addressCtrl.text = data['address'] ?? '';
      govIdCtrl.text = data['govId'] ?? '';
      licenseNoCtrl.text = data['licenseNo'] ?? '';
      regNoCtrl.text = data['motorcycle']?['regNo'] ?? '';
      makeModelCtrl.text = data['motorcycle']?['makeModel'] ?? '';
      yearCtrl.text = data['motorcycle']?['year'] ?? '';
      emergencyNameCtrl.text = data['emergencyContact']?['name'] ?? '';
      emergencyPhoneCtrl.text = data['emergencyContact']?['phone'] ?? '';

      setState(() {
        _driverName = fullNameCtrl.text;
        _driverPhotoUrl = data['profilePhotoUrl'] ?? '';
      });
    }
  }

  // -------------------- TRIP COUNTDOWN --------------------
  void _startTripCountdown() {
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTripTime.inSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() {
          _currentTripTime = Duration(seconds: _currentTripTime.inSeconds - 1);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // -------------------- RIDE NOTIFICATIONS --------------------
  void _listenToPendingRides() {
    _ridesSub = RideService().listenToPendingRides().listen((snapshot) {
      setState(() {
        _pendingRides = snapshot.docs;
        _showAlert = _pendingRides.isNotEmpty;
      });

      // For each pending ride, attempt to resolve pickup/destination labels
      for (final rideDoc in snapshot.docs) {
        final data = rideDoc.data() as Map<String, dynamic>;
        final pickup = data['pickup'] as GeoPoint?;
        final dest = data['destination'] as GeoPoint?;
        final pickupKey = '${rideDoc.id}_pickup';
        final destKey = '${rideDoc.id}_dest';

        if (pickup != null && !_rideAddressCache.containsKey(pickupKey)) {
          resolveLabel(pickup.latitude, pickup.longitude).then((label) {
            final resolved = (label == null || label.isEmpty)
                ? '${pickup.latitude},${pickup.longitude}'
                : label;
            if (mounted) {
              setState(() {
                _rideAddressCache[pickupKey] = resolved;
              });
            }
          });
        }

        if (dest != null && !_rideAddressCache.containsKey(destKey)) {
          resolveLabel(dest.latitude, dest.longitude).then((label) {
            final resolved = (label == null || label.isEmpty)
                ? '${dest.latitude},${dest.longitude}'
                : label;
            if (mounted) {
              setState(() {
                _rideAddressCache[destKey] = resolved;
              });
            }
          });
        }
      }
    });
  }

  Future<void> _acceptRide(String rideId) async {
    final ok = await RideService().acceptRide(rideId: rideId, driverId: uid);
    if (ok) {
      _updater?.stop();
      _updater = LocationUpdater(rideId: rideId);
      await _updater?.start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride accepted. Sharing location...')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride already taken')));
    }
  }

  Future<void> _rejectRide(String rideId) async {
    await RideService().rejectRide(rideId: rideId, driverId: '');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ride rejected')));
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final themeBackground = _isDark
        ? Colors.grey[900]!
        : const Color(0xFFF2F6F9);

    return Scaffold(
      backgroundColor: themeBackground,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDriverProfileCard(),
                  const SizedBox(height: 18),
                  _buildQuickStats(),
                  const SizedBox(height: 18),
                  _buildQuickActions(),
                  const SizedBox(height: 18),
                  _buildLiveTripCard(),
                  const SizedBox(height: 18),
                  _buildEarningsCard(),
                  const SizedBox(height: 18),
                  _buildViewAvailableRidesButton(),
                ],
              ),
            ),
          ),
          if (_showAlert && _pendingRides.isNotEmpty) _buildRideNotifications(),

          if (_showDriverProfile)
            DriverProfile(
              uid: uid,
              onSave: () => setState(() => _showDriverProfile = false),
              onSkip: () => setState(() => _showDriverProfile = false),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.safety_check),
        label: const Text('Emergency'),
        backgroundColor: Colors.redAccent,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // -------------------- APP BAR --------------------
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3E71DF), Color(0xFF00BFA5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.15 * 255).round()),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'eSafeRide - Driver',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Toggle Theme',
                  onPressed: () => setState(() => _isDark = !_isDark),
                  icon: Icon(
                    _isDark ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: 'Logout',
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {},
                  icon: const Icon(Icons.notifications, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- DRIVER CARDS --------------------
  Widget _buildDriverProfileCard() {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.12).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF3E71DF), Color(0xFF00BFA5)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha((0.20 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF00BFA5),
              backgroundImage: _driverPhotoUrl.isNotEmpty
                  ? NetworkImage(_driverPhotoUrl)
                  : null,
              child: _driverPhotoUrl.isEmpty
                  ? Text(
                      _driverName.isNotEmpty
                          ? _driverName.substring(0, 2).toUpperCase()
                          : 'JD',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _driverName.isNotEmpty ? _driverName : 'John Doe',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              const Text(
                'Motorbyk #12 • License ABC123',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => setState(() => _showDriverProfile = true),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    Widget statItem(String title, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        statItem('Active Trips', '2', Icons.directions_bus, Colors.blue),
        const SizedBox(width: 8),
        statItem('Earnings', '\$124', Icons.attach_money, Colors.green),
        const SizedBox(width: 8),
        statItem('Rating', '4.8', Icons.star, Colors.amber),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'Start Trip', 'icon': Icons.play_arrow, 'color': Colors.green},
      {'title': 'End Trip', 'icon': Icons.stop, 'color': Colors.red},
      {'title': 'Mark Pickup', 'icon': Icons.location_on, 'color': Colors.blue},
      {'title': 'Mark Drop', 'icon': Icons.flag, 'color': Colors.orange},
      {'title': 'Messages', 'icon': Icons.message, 'color': Colors.purple},
    ];

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = actions[i];
          final Color itemColor = item['color'] as Color;
          final IconData itemIcon = item['icon'] as IconData;
          final String itemTitle = item['title'] as String;
          return GestureDetector(
            onTap: () {},
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    itemColor.withAlpha((0.9 * 255).round()),
                    Colors.white,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: itemColor.withAlpha((0.2 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: itemColor.withAlpha((0.2 * 255).round()),
                    child: Icon(itemIcon, color: itemColor),
                  ),
                  const Spacer(),
                  Text(
                    itemTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTripCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(
                      ((0.12 * (1 + _pulseController.value)) * 255).round(),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_currentTripTime),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Earnings: \$452',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildViewAvailableRidesButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AvailableRidesPage()),
        );
      },
      icon: const Icon(Icons.directions_car),
      label: const Text('View All Available Rides'),
    );
  }

  // -------------------- RIDE ALERT --------------------
  Widget _buildRideNotifications() {
    return Positioned(
      bottom: 140,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.yellow[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellow.shade700),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have ${_pendingRides.length} pending ride request(s)!',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _showAlert = false),
                  icon: const Icon(Icons.close, color: Colors.orange),
                ),
              ],
            ),
            const Divider(),
            ..._pendingRides.map((ride) {
              final rideId = ride.id;
              final data = ride.data() as Map<String, dynamic>;
              final pickup = data['pickup'] as GeoPoint?;
              final dest = data['destination'] as GeoPoint?;
              final pickupKey = '${rideId}_pickup';
              final destKey = '${rideId}_dest';

              final pickupLabel =
                  _rideAddressCache[pickupKey] ??
                  (pickup != null
                      ? '${pickup.latitude},${pickup.longitude}'
                      : 'Unknown');
              final destLabel =
                  _rideAddressCache[destKey] ??
                  (dest != null
                      ? '${dest.latitude},${dest.longitude}'
                      : 'Unknown');

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Ride $rideId: $pickupLabel → $destLabel'),
                  ),
                  TextButton(
                    onPressed: () => _acceptRide(rideId),
                    child: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _rejectRide(rideId),
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: const Color(0xFF3E71DF),
      unselectedItemColor: Colors.grey[500],
      onTap: (index) {
        if (index == 1) setState(() => _showDriverProfile = true);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}
