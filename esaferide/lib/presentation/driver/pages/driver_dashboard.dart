import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/config/routes.dart';
import 'package:esaferide/presentation/driver/pages/driver_profile.dart';

class DriverDashboard extends StatefulWidget {
  final String uid;
  const DriverDashboard({super.key, required this.uid});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with SingleTickerProviderStateMixin {
  bool _isDark = false;
  late final AnimationController _pulseController;
  Timer? _tripTimer;
  Duration _currentTripTime = const Duration(minutes: 12);

  // Overlay & profile
  bool _showDriverProfile = false;
  // tracked when profile is saved; not used in UI currently

  // Driver info
  String _driverName = '';
  String _driverPhotoUrl = '';

  // Image picking
  // ImagePicker is used inside DriverProfile; dashboard does not pick images directly
  File? idFile, licenseFile, profilePhoto, motorcyclePhoto;

  // Colors
  static const Color _primaryStart = Color(0xFF3E71DF);
  static const Color _primaryEnd = Color(0xFF00BFA5);
  static const Color _accentSoft = Color(0xFFEEF6FF);

  // Form controllers
  final _formKey = GlobalKey<FormState>();
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

  // local saving flag handled inside DriverProfile; not used here
  bool _showAlert = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startTripCountdown();
    _checkProfileCompletion();
  }

  // -------------------- PROFILE LOGIC --------------------
  Future<void> _checkProfileCompletion() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.uid)
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // show saving handled by the overlay form; dashboard doesn't track _isSaving now

    String? idUrl = idFile != null
        ? await _uploadFile(idFile!, 'drivers/${widget.uid}/id.jpg')
        : null;
    String? licenseUrl = licenseFile != null
        ? await _uploadFile(licenseFile!, 'drivers/${widget.uid}/license.jpg')
        : null;
    String? profileUrl = profilePhoto != null
        ? await _uploadFile(profilePhoto!, 'drivers/${widget.uid}/profile.jpg')
        : null;
    String? motorcycleUrl = motorcyclePhoto != null
        ? await _uploadFile(
            motorcyclePhoto!,
            'drivers/${widget.uid}/motorcycle.jpg',
          )
        : null;

    await FirebaseFirestore.instance.collection('drivers').doc(widget.uid).set({
      'fullName': fullNameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'govId': govIdCtrl.text.trim(),
      'govIdUrl': idUrl,
      'licenseNo': licenseNoCtrl.text.trim(),
      'licenseUrl': licenseUrl,
      'profilePhotoUrl': profileUrl,
      'motorcycle': {
        'regNo': regNoCtrl.text.trim(),
        'makeModel': makeModelCtrl.text.trim(),
        'year': yearCtrl.text.trim(),
        'photoUrl': motorcycleUrl,
      },
      'emergencyContact': {
        'name': emergencyNameCtrl.text.trim(),
        'phone': emergencyPhoneCtrl.text.trim(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _showDriverProfile = false;
      _driverName = fullNameCtrl.text;
      _driverPhotoUrl = profileUrl ?? '';
    });
  }

  Future<String?> _uploadFile(File file, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // File picking is handled by `DriverProfile` widget; dashboard no longer needs _pickFile

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

  @override
  void dispose() {
    _pulseController.dispose();
    _tripTimer?.cancel();
    super.dispose();
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
                ],
              ),
            ),
          ),
          if (_showAlert) _buildFloatingAlert(),

          // Overlay for DriverProfile
          if (_showDriverProfile)
            DriverProfile(
              uid: widget.uid,
              onSave: _saveProfile,
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

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryStart, _primaryEnd],
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
                    colors: [_primaryStart, _primaryEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryStart.withAlpha((0.20 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            CircleAvatar(
              radius: 30,
              backgroundColor: _primaryEnd,
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
                'Bus #12 • License ABC123',
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
        statItem('Active Trips', '2', Icons.directions_bus, _primaryStart),
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
                    _accentSoft,
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
                    color: _primaryEnd.withAlpha(
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

  Widget _buildFloatingAlert() {
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
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You have a pending trip request!',
                style: TextStyle(color: Colors.orange[800]),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _showAlert = false),
              icon: const Icon(Icons.close, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: _primaryStart,
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
