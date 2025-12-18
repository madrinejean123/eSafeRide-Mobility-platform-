import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentProfile extends StatefulWidget {
  final VoidCallback onClose;

  const StudentProfile({
    super.key,
    required this.onClose,
    required Null Function() onSkip,
  });

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  final _fullNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Accessibility checkboxes
  bool _wheelchair = false;
  bool _assistance = false;
  bool _visual = false;
  bool _hearing = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _fullNameController.text = data['fullName'] ?? '';
          _regNumberController.text = data['regNumber'] ?? '';
          _courseController.text = data['course'] ?? '';
          _yearController.text = data['year'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emergencyNameController.text = data['emergencyName'] ?? '';
          _emergencyPhoneController.text = data['emergencyPhone'] ?? '';
          final accessibility = data['accessibility'] ?? {};
          _wheelchair = accessibility['wheelchair'] ?? false;
          _assistance = accessibility['assistance'] ?? false;
          _visual = accessibility['visual'] ?? false;
          _hearing = accessibility['hearing'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('students').doc(user.uid).set(
        {
          'fullName': _fullNameController.text,
          'regNumber': _regNumberController.text,
          'course': _courseController.text,
          'year': _yearController.text,
          'phone': _phoneController.text,
          'emergencyName': _emergencyNameController.text,
          'emergencyPhone': _emergencyPhoneController.text,
          'accessibility': {
            'wheelchair': _wheelchair,
            'assistance': _assistance,
            'visual': _visual,
            'hearing': _hearing,
          },
        },
        SetOptions(merge: true),
      );

      widget.onClose();
    } catch (e) {
      debugPrint('Error saving profile: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black.withAlpha((0.45 * 255).round()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFB),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: const [
                        Icon(Icons.badge_outlined, color: Color(0xFF3E71DF)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Complete Your Student Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This helps us provide safe and accessible rides tailored to your needs.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Basic Info
                    _sectionTitle('Basic Information'),
                    _inputField('Full Name', controller: _fullNameController),
                    _inputField(
                      'Registration Number',
                      controller: _regNumberController,
                    ),
                    _inputField(
                      'Course / Program',
                      controller: _courseController,
                    ),
                    _inputField(
                      'Year of Study (1–5)',
                      controller: _yearController,
                      keyboard: TextInputType.number,
                    ),
                    _inputField(
                      'Your Phone Number',
                      controller: _phoneController,
                      keyboard: TextInputType.phone,
                    ),

                    const SizedBox(height: 12),

                    // Accessibility Needs
                    _sectionTitle('Accessibility Needs'),
                    _checkItem(
                      'Wheelchair access required',
                      _wheelchair,
                      (v) => setState(() => _wheelchair = v ?? false),
                    ),
                    _checkItem(
                      'Assistance when boarding',
                      _assistance,
                      (v) => setState(() => _assistance = v ?? false),
                    ),
                    _checkItem(
                      'Visual guidance / alerts',
                      _visual,
                      (v) => setState(() => _visual = v ?? false),
                    ),
                    _checkItem(
                      'Hearing-friendly alerts',
                      _hearing,
                      (v) => setState(() => _hearing = v ?? false),
                    ),

                    const SizedBox(height: 12),

                    // Emergency Contact
                    _sectionTitle('Emergency Contact'),
                    _inputField(
                      'Contact Name',
                      controller: _emergencyNameController,
                    ),
                    _inputField(
                      'Phone Number',
                      controller: _emergencyPhoneController,
                      keyboard: TextInputType.phone,
                    ),

                    const SizedBox(height: 18),

                    // Actions
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3E71DF),
                                          Color(0xFF00BFA5),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Save & Continue',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 8),

                    Center(
                      child: TextButton(
                        onPressed: widget.onClose,
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  static Widget _inputField(
    String hint, {
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  static Widget _checkItem(
    String label,
    bool value,
    ValueChanged<bool?>? onChanged,
  ) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _regNumberController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }
}
