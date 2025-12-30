import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DriverProfile extends StatefulWidget {
  final String uid; // Firebase Auth UID of the driver
  final VoidCallback onSave;
  final VoidCallback onSkip;

  const DriverProfile({
    super.key,
    required this.uid,
    required this.onSave,
    required this.onSkip,
  });

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final _formKey = GlobalKey<FormState>();

  // ---- Text controllers ----
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

  // ---- Upload files (store XFile from image_picker)
  XFile? idFile;
  XFile? licenseFile;
  XFile? profilePhoto;
  XFile? motorcyclePhoto;
  // Stored URLs from Firestore for existing uploads
  String? govIdUrl;
  String? licenseUrl;
  String? profilePhotoUrl;
  String? motorcyclePhotoUrl;

  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.uid)
          .get();

      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
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
          govIdUrl = data['govIdUrl'] as String?;
          licenseUrl = data['licenseUrl'] as String?;
          profilePhotoUrl = data['profilePhotoUrl'] as String?;
          motorcyclePhotoUrl = data['motorcycle']?['photoUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
    }
  }

  // ---- Pick an image from gallery ----
  Future<void> _pickFile(String type) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;

      setState(() {
        switch (type) {
          case 'id':
            idFile = picked;
            break;
          case 'license':
            licenseFile = picked;
            break;
          case 'profile':
            profilePhoto = picked;
            break;
          case 'motorcycle':
            motorcyclePhoto = picked;
            break;
        }
      });
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick file')));
    }
  }

  // ---- Upload a file to Firebase Storage ----
  Future<String?> _uploadFile(XFile file, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final bytes = await file.readAsBytes();
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // ---- Save profile to Firestore ----
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    bool success = false;
    try {
      // Upload files with timeouts to avoid indefinite hanging
      final idUrl = idFile != null
          ? await _uploadFile(
              idFile!,
              'drivers/${widget.uid}/id.jpg',
            ).timeout(const Duration(seconds: 30))
          : null;
      final licenseUrl = licenseFile != null
          ? await _uploadFile(
              licenseFile!,
              'drivers/${widget.uid}/license.jpg',
            ).timeout(const Duration(seconds: 30))
          : null;
      final profileUrl = profilePhoto != null
          ? await _uploadFile(
              profilePhoto!,
              'drivers/${widget.uid}/profile.jpg',
            ).timeout(const Duration(seconds: 30))
          : null;
      final motorcycleUrl = motorcyclePhoto != null
          ? await _uploadFile(
              motorcyclePhoto!,
              'drivers/${widget.uid}/motorcycle.jpg',
            ).timeout(const Duration(seconds: 30))
          : null;

      // Build Firestore data
      final data = {
        'fullName': fullNameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'govId': govIdCtrl.text.trim(),
        if (idUrl != null) 'govIdUrl': idUrl,
        'licenseNo': licenseNoCtrl.text.trim(),
        if (licenseUrl != null) 'licenseUrl': licenseUrl,
        if (profileUrl != null) 'profilePhotoUrl': profileUrl,
        'motorcycle': {
          'regNo': regNoCtrl.text.trim(),
          'makeModel': makeModelCtrl.text.trim(),
          'year': yearCtrl.text.trim(),
          if (motorcycleUrl != null) 'photoUrl': motorcycleUrl,
        },
        'emergencyContact': {
          'name': emergencyNameCtrl.text.trim(),
          'phone': emergencyPhoneCtrl.text.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        // mark as pending verification so admins can review before activation
        'status': 'pending',
        'verified': false,
        'submittedAt': FieldValue.serverTimestamp(),
      };

      // Write driver doc with timeout
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.uid)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 30));

      // Create a simple admin notification document so admins can listen
      // to new submissions. This is a lightweight approach; you can replace
      // with Cloud Functions or a more advanced notifications schema later.
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'type': 'driver_submission',
            'driverId': widget.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          })
          .timeout(const Duration(seconds: 10));

      success = true;
    } on TimeoutException catch (e) {
      debugPrint('Timeout while saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Operation timed out. Check your connection and try again.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile. Try again.')),
        );
      }
    } finally {
      // Always clear the saving flag if the widget is still mounted.
      if (mounted) setState(() => _isSaving = false);
    }

    // Handle success UI/navigation after the try/catch/finally block to
    // avoid control-flow changes inside `finally` and to ensure we don't
    // use the BuildContext when the widget is unmounted.
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile submitted — please wait for admin verification.',
          ),
        ),
      );
      widget.onSave();
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete Your Driver Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This helps us verify you and provide safe rides for students.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Personal Information'),
                      _inputField('Full Name', fullNameCtrl),
                      _inputField(
                        'Phone Number',
                        phoneCtrl,
                        keyboard: TextInputType.phone,
                      ),
                      _inputField(
                        'Email',
                        emailCtrl,
                        keyboard: TextInputType.emailAddress,
                      ),
                      _inputField('Address (Optional)', addressCtrl),

                      const SizedBox(height: 12),
                      _sectionTitle('Verification'),
                      _inputField('Government ID Number', govIdCtrl),
                      _uploadField('Upload ID Document', 'id'),
                      _inputField('Motorcycle License Number', licenseNoCtrl),
                      _uploadField('Upload License', 'license'),
                      _uploadField('Profile Photo', 'profile'),

                      const SizedBox(height: 12),
                      _sectionTitle('Motorcycle Details'),
                      _inputField('Registration Number', regNoCtrl),
                      _inputField('Make & Model', makeModelCtrl),
                      _inputField('Year of Manufacture', yearCtrl),
                      _uploadField('Motorcycle Photo', 'motorcycle'),

                      const SizedBox(height: 12),
                      _sectionTitle('Emergency Contact'),
                      _inputField('Contact Name', emergencyNameCtrl),
                      _inputField(
                        'Phone Number',
                        emergencyPhoneCtrl,
                        keyboard: TextInputType.phone,
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () async {
                                      await _saveProfile();
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save & Continue',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: widget.onSkip,
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
      ),
    );
  }

  // ---- Helpers ----
  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 10),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _inputField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        // Allow empty values and save whatever the user provided (mirrors
        // StudentProfile behavior). Validation was blocking saves when fields
        // were left empty.
        validator: null,
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

  Widget _uploadField(String label, String type) {
    XFile? file;
    switch (type) {
      case 'id':
        file = idFile;
        break;
      case 'license':
        file = licenseFile;
        break;
      case 'profile':
        file = profilePhoto;
        break;
      case 'motorcycle':
        file = motorcyclePhoto;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _pickFile(type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.upload_file, color: Colors.grey),
              const SizedBox(width: 8),
              if (file != null)
                Expanded(
                  child: Text(
                    'Selected File',
                    style: const TextStyle(color: Colors.black),
                  ),
                )
              else if (type == 'profile' && profilePhotoUrl != null)
                Expanded(
                  child: Row(
                    children: [
                      Image.network(
                        profilePhotoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                    ],
                  ),
                )
              else if (type == 'motorcycle' && motorcyclePhotoUrl != null)
                Expanded(
                  child: Row(
                    children: [
                      Image.network(
                        motorcyclePhotoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                    ],
                  ),
                )
              else if (type == 'id' && govIdUrl != null)
                Expanded(
                  child: Row(
                    children: [
                      Image.network(
                        govIdUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                    ],
                  ),
                )
              else if (type == 'license' && licenseUrl != null)
                Expanded(
                  child: Row(
                    children: [
                      Image.network(
                        licenseUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Text(label, style: TextStyle(color: Colors.grey[600])),
                ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
