import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esaferide/config/routes.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with SingleTickerProviderStateMixin {
  bool _isDark = false;
  late AnimationController _pulseController;
  Timer? _tripTimer;
  Duration _currentTripTime = const Duration(minutes: 12, seconds: 0);
  bool _showAlert = true;

  // Colors matching the student dashboard
  static const Color _primaryStart = Color(0xFF3E71DF);
  static const Color _primaryEnd = Color(0xFF00BFA5);
  static const Color _cardBg = Color(0xFFF7FAFB);
  static const Color _accentSoft = Color(0xFFEEF6FF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startTripCountdown();
  }

  void _startTripCountdown() {
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTripTime.inSeconds <= 0)
        timer.cancel();
      else
        setState(() {
          _currentTripTime = Duration(seconds: _currentTripTime.inSeconds - 1);
        });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tripTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final themeBackground = _isDark
        ? Colors.grey[900]!
        : const Color(0xFFF2F6F9);

    return Scaffold(
      backgroundColor: themeBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriverProfile(),
              const SizedBox(height: 18),
              _buildQuickStats(),
              const SizedBox(height: 18),
              _buildQuickActions(),
              const SizedBox(height: 18),
              _buildLiveTripCard(),
              const SizedBox(height: 18),
              _buildEarningsCard(),
              const SizedBox(height: 18),
              if (_showAlert) _buildFloatingAlert(),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE047),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
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

  // ----------------- APP BAR -----------------
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('eSafeRide - Driver'),
      centerTitle: true,
      backgroundColor: _primaryStart,
      actions: [
        IconButton(
          tooltip: 'Toggle Theme',
          onPressed: () => setState(() => _isDark = !_isDark),
          icon: Icon(_isDark ? Icons.dark_mode : Icons.light_mode),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications),
        ),
      ],
    );
  }

  // ----------------- PROFILE -----------------
  Widget _buildDriverProfile() {
    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: _primaryEnd,
          child: const Icon(Icons.person, color: Colors.white, size: 36),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Welcome back,', style: TextStyle(color: Colors.grey)),
              Text(
                'John Doe',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Vehicle: Bus #12 • License: ABC123',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
      ],
    );
  }

  // ----------------- QUICK STATS -----------------
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

  // ----------------- QUICK ACTIONS -----------------
  Widget _buildQuickActions() {
    final List<Map<String, dynamic>> actions = [
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
          return GestureDetector(
            onTap: () {},
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [item['color'].withOpacity(0.9), _accentSoft],
                ),
                boxShadow: [
                  BoxShadow(
                    color: item['color'].withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: item['color'].withOpacity(0.2),
                    child: Icon(item['icon'], color: item['color']),
                  ),
                  const Spacer(),
                  Text(
                    item['title'],
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

  // ----------------- LIVE TRIP -----------------
  Widget _buildLiveTripCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Trip',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Route: Dormitory → Main Campus',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
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
                        color: _primaryEnd.withOpacity(
                          0.12 * (1 + _pulseController.value),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatDuration(_currentTripTime)} min',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: 1 - (_currentTripTime.inSeconds / 720),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryEnd),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- EARNINGS -----------------
  Widget _buildEarningsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Weekly Earnings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Completed Trips: 15', style: TextStyle(color: Colors.grey)),
            Text(
              'Total: \$320',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- ALERT -----------------
  Widget _buildFloatingAlert() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Traffic delay on Route 3. Adjust route!'),
          ),
          IconButton(
            onPressed: () => setState(() => _showAlert = false),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  // ----------------- BOTTOM NAV -----------------
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      selectedItemColor: _primaryStart,
      unselectedItemColor: Colors.grey[500],
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_bus),
          label: 'Trips',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Earnings'),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}
