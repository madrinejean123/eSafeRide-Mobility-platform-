import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/notifications_widget.dart';

class DriverNotificationsPage extends StatelessWidget {
  const DriverNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: NotificationsList(),
      ),
    );
  }
}
