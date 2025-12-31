import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/styles.dart';

/// Lightweight currency formatter (no intl dependency).
String formatCurrency(dynamic amount) {
  if (amount == null) return 'UGX —';
  final n = num.tryParse(amount.toString()) ?? 0;
  final rounded = n.round();
  final s = rounded.toString();
  final chars = s.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < chars.length; i++) {
    out.add(chars[i]);
    if ((i + 1) % 3 == 0 && i != chars.length - 1) out.add(',');
  }
  final joined = out.reversed.join();
  return 'UGX $joined';
}

/// Shorten long place labels by taking the first two comma-separated parts.
String shortPlaceLabel(String? label) {
  if (label == null || label.trim().isEmpty) return '';
  final parts = label
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts[0]}, ${parts[1]}';
}

/// A small, consistent tile used for completed/past ride items across pages.
class CompletedRideTile extends StatelessWidget {
  final String avatarText;
  final String title; // primary line, e.g. rider/driver name or ride id
  final String? pickupLabel;
  final String? destinationLabel;
  final String fareLabel;
  final String timeLabel;
  final VoidCallback? onView;

  const CompletedRideTile({
    super.key,
    required this.avatarText,
    required this.title,
    this.pickupLabel,
    this.destinationLabel,
    required this.fareLabel,
    required this.timeLabel,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          child: Text(
            avatarText.isNotEmpty ? avatarText[0].toUpperCase() : '?',
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pickupLabel != null && pickupLabel!.isNotEmpty)
              Text(
                'Pickup: ${shortPlaceLabel(pickupLabel)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (destinationLabel != null && destinationLabel!.isNotEmpty)
              Text(
                'Dest: ${shortPlaceLabel(destinationLabel)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(fareLabel, style: subtleStyle()),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeLabel, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (onView != null)
              TextButton(onPressed: onView, child: const Text('View')),
          ],
        ),
      ),
    );
  }
}
