import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// desktop pointer helpers were removed; keep imports minimal

import 'package:esaferide/config/routes.dart';
import 'package:esaferide/presentation/auth/login_page.dart';
import 'package:esaferide/presentation/driver/pages/driver_profile.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/chat/conversation_list_page.dart';
import 'package:esaferide/presentation/chat/user_list_page.dart';
import 'package:esaferide/presentation/driver/pages/driver_ride_tracking_page.dart';

import '../../../data/services/ride_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/geocode_service.dart'; // ✅ WEB + MOBILE SAFE
import 'available_rides_page.dart';
import 'completed_jobs_page.dart';

/// -------------------- ADDRESS CACHE --------------------
class AddressCacheEntry {
  final String? label;
  final DateTime fetchedAt;

  AddressCacheEntry({this.label, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > const Duration(minutes: 10);
}

/// -------------------- DRIVER DASHBOARD --------------------
class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with SingleTickerProviderStateMixin {
  String uid = '';

  late AnimationController _pulseController;
  Timer? _tripTimer;
  StreamSubscription<QuerySnapshot>? _ridesSub;
  StreamSubscription<QuerySnapshot>? _tripsSub;

  bool _tripActive = false;

  int _prevPendingCount = 0;

  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;

  final bool _isDark = false;

  List<QueryDocumentSnapshot> _pendingRides = [];
  final Map<String, AddressCacheEntry> _rideAddressCache = {};

  Duration _currentTripTime = Duration.zero;

  int _bottomIndex = 0;

  // visible driver stats
  int _tripsCompleted = 0;
  double _earnings = 124.0;
  final double _rating = 4.8;

  String _driverName = '';
  String _driverPhotoUrl = '';

  // -------------------- CONTROLLERS --------------------
  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final govIdCtrl = TextEditingController();
  final licenseNoCtrl = TextEditingController();
  final regNoCtrl = TextEditingController();
  final makeModelCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  final emergencyNameCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

  // -------------------- INIT --------------------
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
    );

    if (isMobile) {
      _pulseController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
      _listenToPendingRides();
      _subscribeToTripsCount();
    });
  }

  // -------------------- DISPOSE --------------------
  @override
  void dispose() {
    _pulseController.dispose();
    _tripTimer?.cancel();
    _ridesSub?.cancel();
    _tripsSub?.cancel();
    // LocationUpdater is started from AvailableRidesPage when a ride is accepted.

    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    govIdCtrl.dispose();
    licenseNoCtrl.dispose();
    regNoCtrl.dispose();
    makeModelCtrl.dispose();
    yearCtrl.dispose();
    emergencyNameCtrl.dispose();
    emergencyPhoneCtrl.dispose();

    super.dispose();
  }

  // -------------------- PROFILE --------------------
  Future<void> _checkProfileCompletion() async {
    if (uid.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();

    if (!doc.exists || doc.data() == null) return;

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

    if (!mounted) return;

    setState(() {
      _driverName = fullNameCtrl.text;
      _driverPhotoUrl = data['profilePhotoUrl'] ?? '';
    });
  }

  void _subscribeToTripsCount() {
    if (uid.isEmpty) return;
    try {
      _tripsSub = FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            if (!mounted) return;
            setState(() {
              _tripsCompleted = snap.docs.length;
            });
          });
    } catch (e) {
      debugPrint('Failed to subscribe to trips count: $e');
    }
  }

  // -------------------- TRIP TIMER (start/stop) --------------------
  void _startTrip() {
    if (_tripActive) return;
    _tripTimer?.cancel();
    setState(() {
      _tripActive = true;
      _currentTripTime = Duration.zero;
    });
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _currentTripTime = Duration(seconds: _currentTripTime.inSeconds + 1);
      });
    });
  }

  void _endTrip() {
    if (!_tripActive) return;
    _tripTimer?.cancel();
    // compute a simple fare and increment trip count
    final completed = _currentTripTime;
    final fare = 5.0 + (completed.inMinutes * 0.5);
    setState(() {
      _tripActive = false;
      _tripsCompleted = _tripsCompleted + 1;
      _earnings = double.parse((_earnings + fare).toStringAsFixed(2));
      // clear the current trip timer display
      _currentTripTime = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // -------------------- RIDES --------------------
  void _listenToPendingRides() {
    _ridesSub = RideService().listenToPendingRides().listen((snapshot) {
      final filtered = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final rejected = List<String>.from(data['rejectedDrivers'] ?? []);
        return !rejected.contains(uid);
      }).toList();

      if (!mounted) return;

      setState(() => _pendingRides = filtered);

      if (filtered.isNotEmpty && _prevPendingCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have ${filtered.length} pending ride request(s)',
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AvailableRidesPage()),
                );
              },
            ),
          ),
        );
      }
      _prevPendingCount = filtered.length;

      for (final rideDoc in snapshot.docs) {
        final data = rideDoc.data() as Map<String, dynamic>;
        final pickup = data['pickup'] as GeoPoint?;
        final dest = data['destination'] as GeoPoint?;

        Future<void> resolve(GeoPoint gp, String key) async {
          final label = await resolveLabel(gp.latitude, gp.longitude);
          if (!mounted) return;

          setState(() {
            _rideAddressCache[key] = AddressCacheEntry(
              label: label ?? '${gp.latitude},${gp.longitude}',
              fetchedAt: DateTime.now(),
            );
          });
        }

        if (pickup != null) {
          final k = '${rideDoc.id}_pickup';
          if (_rideAddressCache[k]?.isExpired ?? true) {
            resolve(pickup, k);
          }
        }

        if (dest != null) {
          final k = '${rideDoc.id}_dest';
          if (_rideAddressCache[k]?.isExpired ?? true) {
            resolve(dest, k);
          }
        }
      }
    });
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final themeBackground = _isDark
        ? Colors.grey[900]!
        : const Color(0xFFF2F6F9);

    return Scaffold(
      backgroundColor: themeBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: kAppGradient,
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
                  const Text(
                    'eSafeRide - Driver',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) {
                          return SizedBox(
                            height: 360,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Notifications',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Expanded(
                                    child: Center(
                                      child: Text('No notifications'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.notifications, color: Colors.white),
                  ),
                  StreamBuilder<int>(
                    stream: ChatService().streamTotalUnreadForUser(uid),
                    builder: (context, snapshot) {
                      final unread = snapshot.data ?? 0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Messages',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ConversationListPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.chat_bubble,
                              color: Colors.white,
                            ),
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 6,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    unread > 99 ? '99+' : unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      nav.pushReplacementNamed(AppRoutes.login);
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDriverProfileHeader(),
            const SizedBox(height: 12),
            if (_pendingRides.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'You have ${_pendingRides.length} pending ride request(s)',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              ),
            const SizedBox(height: 6),
            _buildQuickStats(),
            const SizedBox(height: 18),
            _buildQuickActions(),
            const SizedBox(height: 18),
            _buildLiveTripCard(),
            const SizedBox(height: 18),
            _buildEarningsCard(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _buildViewAvailableRidesButton()),
                const SizedBox(width: 12),
                Expanded(child: _buildViewCompletedJobsButton()),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserListPage()),
              );
            },
            child: const Icon(Icons.chat),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'emergency',
            onPressed: () {},
            icon: const Icon(Icons.safety_check),
            label: const Text('Emergency'),
            backgroundColor: kPrimaryTeal,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // profile header styled like the Student dashboard
  Widget _buildDriverProfileHeader() {
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
                  gradient: kAppGradient,
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryBlue.withAlpha((0.20 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            CircleAvatar(
              radius: 30,
              backgroundColor: kPrimaryTeal,
              backgroundImage: _driverPhotoUrl.isNotEmpty
                  ? NetworkImage(_driverPhotoUrl)
                  : null,
              child: _driverPhotoUrl.isEmpty
                  ? Text(
                      _driverName.isNotEmpty
                          ? (_driverName.length >= 2
                                    ? _driverName.substring(0, 2)
                                    : _driverName.substring(0, 1))
                                .toUpperCase()
                          : 'DR',
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
              ),
              const SizedBox(height: 6),
              const Text(
                'Driver • Motorbyk #12',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => _openDriverProfile(),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    Widget statCard(
      String title,
      String value,
      List<Color> colors,
      IconData icon, {
      VoidCallback? onTap,
    }) => Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.04 * 255).round()),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        statCard(
          'Trips',
          '$_tripsCompleted',
          [const Color(0xFFE8F7FF), const Color(0xFFBEE9FF)],
          Icons.directions_bike,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompletedJobsPage()),
            );
          },
        ),
        statCard('Earnings', '\$${_earnings.toStringAsFixed(2)}', [
          const Color(0xFFFFE8F0),
          const Color(0xFFFFC6DD),
        ], Icons.attach_money),
        statCard('Rating', _rating.toStringAsFixed(1), [
          const Color(0xFFFFF8E1),
          const Color(0xFFFFF0B3),
        ], Icons.star),
      ],
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: Card(
              child: SizedBox(
                height: 120,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Trip',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tripActive
                              ? Colors.red
                              : Colors.green,
                          minimumSize: const Size(120, 40),
                        ),
                        onPressed: _tripActive ? _endTrip : _startTrip,
                        child: Text(_tripActive ? 'Stop' : 'Start'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTripCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Trip Time: ${_formatDuration(_currentTripTime)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Earnings: \$${_earnings.toStringAsFixed(2)}'),
      ),
    );
  }

  Widget _buildViewAvailableRidesButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AvailableRidesPage()),
        );
      },
      child: const Text('View Available Rides'),
    );
  }

  Widget _buildViewCompletedJobsButton() {
    return OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompletedJobsPage()),
        );
      },
      child: const Text('View Completed Jobs'),
    );
  }

  // Profile editor is opened via the centralized `_openDriverProfile`
  // implementation later in this file which provides the required
  // callbacks (`onSave` / `onSkip`) for `DriverProfile`.

  Future<void> _openDriverProfile({bool recheckAfterSave = true}) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                controller: controller,
                child: DriverProfile(
                  uid: uid,
                  onSave: () {
                    Navigator.of(context).pop();
                    if (recheckAfterSave && mounted) _checkProfileCompletion();
                  },
                  onSkip: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (i) async {
        setState(() => _bottomIndex = i);
        if (i == 1) {
          _openDriverProfile();
          return;
        }
        // Map / current ride
        if (i == 2) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final rideId = await RideService().findActiveRideForDriver(user.uid);
          if (rideId == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('No active ride')));
            return;
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverRideTrackingPage(rideId: rideId),
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
      ],
    );
  }
}
