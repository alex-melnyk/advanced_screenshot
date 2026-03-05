import 'package:flutter/widgets.dart';

/// A warning banner displayed when the screenshot server is running
/// in release mode.
///
/// Shows a prominent red bar at the top of the screen to indicate that
/// the screenshot server is active in a non-debug build. This serves as
/// a visual reminder that the build should not be shipped to end users.
class ScreenshotSecurityBanner extends StatelessWidget {
  /// Creates a [ScreenshotSecurityBanner].
  const ScreenshotSecurityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: const Color(0xFFD32F2F),
        child: const Text(
          '\u26A0 Screenshot server is active (RELEASE MODE)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
