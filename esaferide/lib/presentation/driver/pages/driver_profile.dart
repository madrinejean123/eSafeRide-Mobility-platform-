import 'dart:io';
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

  // ---- Upload files ----
  File? idFile;
  File? licenseFile;
  File? profilePhoto;
  File? motorcyclePhoto;

  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFile(String type) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      switch (type) {
        case 'id':
          idFile = File(picked.path);
          break;
        case 'license':
          licenseFile = File(picked.path);
          break;
        case 'profile':
          profilePhoto = File(picked.path);
          break;
        case 'motorcycle':
          motorcyclePhoto = File(picked.path);
          break;
      }
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Upload files
    final idUrl = idFile != null
        ? await _uploadFile(idFile!, 'drivers/${widget.uid}/id.jpg')
        : null;
    final licenseUrl = licenseFile != null
        ? await _uploadFile(licenseFile!, 'drivers/${widget.uid}/license.jpg')
        : null;
    final profileUrl = profilePhoto != null
        ? await _uploadFile(profilePhoto!, 'drivers/${widget.uid}/profile.jpg')
        : null;
    final motorcycleUrl = motorcyclePhoto != null
        ? await _uploadFile(
            motorcyclePhoto!,
            'drivers/${widget.uid}/motorcycle.jpg',
          )
        : null;

    // Save Firestore data
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

    setState(() => _isSaving = false);

    widget.onSave();
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
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
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
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
    File? file;
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
              Expanded(
                child: Text(
                  file != null ? 'Selected File' : label,
                  style: TextStyle(
                    color: file != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
