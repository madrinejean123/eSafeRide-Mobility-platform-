import 'package:flutter/material.dart';

// Centralized app colors and small helpers to keep UI consistent.
const Color kPrimaryBlue = Color(0xFF3E71DF);
const Color kPrimaryTeal = Color(0xFF00BFA5);
const LinearGradient kAppGradient = LinearGradient(
  colors: [kPrimaryBlue, kPrimaryTeal],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

BoxDecoration cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
);

ButtonStyle primaryButtonStyle() => ElevatedButton.styleFrom(
  backgroundColor: kPrimaryBlue,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
);

TextStyle sectionTitleStyle() => const TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: Colors.black87,
);

TextStyle subtleStyle() => const TextStyle(color: Colors.grey, fontSize: 12);

// Small helper to create a rounded card wrapper around content.
Widget styledCard({required Widget child, EdgeInsets? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(12),
    decoration: cardDecoration(),
    child: child,
  );
}
