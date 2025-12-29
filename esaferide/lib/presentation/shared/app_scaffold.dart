import 'package:flutter/material.dart';

/// A small reusable scaffold that matches the Driver dashboard's visual style
/// (gradient app bar with rounded bottom and light background). Use this to
/// keep pages visually consistent across the app.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBackButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBackButton = true,
  });

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3E71DF), Color(0xFF00BFA5)],
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
                // Show an icon-only back affordance when the Navigator can pop
                // and the page allows it. Sub-pages should keep the back
                // button while top-level pages (eg. dashboards) can disable it
                // by setting `showBackButton: false` on the scaffold.
                if (showBackButton && Navigator.canPop(context))
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeBackground = const Color(0xFFF2F6F9);
    return Scaffold(
      backgroundColor: themeBackground,
      appBar: _buildAppBar(context),
      body: SafeArea(child: child),
    );
  }
}
