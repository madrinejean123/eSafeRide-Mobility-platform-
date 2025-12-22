import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/styles.dart';

Widget statCard(String title, String value, {IconData? icon, Color? color}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: cardDecoration(),
    child: Row(
      children: [
        if (icon != null)
          CircleAvatar(
            backgroundColor: (color ?? kPrimaryBlue).withAlpha(40),
            child: Icon(icon, color: color ?? kPrimaryBlue),
          ),
        if (icon != null) const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ],
    ),
  );
}

class SimpleBarChart extends StatelessWidget {
  final List<int> values;
  final Color color;

  const SimpleBarChart({
    super.key,
    required this.values,
    this.color = kPrimaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final h = (v / max) * 56;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

Widget sectionHeader(String title, {Widget? trailing}) {
  return Row(
    children: [
      Expanded(child: Text(title, style: sectionTitleStyle())),
      if (trailing != null) trailing,
    ],
  );
}
