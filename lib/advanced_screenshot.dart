/// A Flutter package that provides remote screenshot capture via a built-in
/// debug HTTP server.
///
/// Take screenshots of your running Flutter app from any terminal or CI
/// script — works on all platforms.
///
/// ## Quick Start
///
/// Wrap your app root with [ScreenshotServer]:
///
/// ```dart
/// import 'package:advanced_screenshot/advanced_screenshot.dart';
///
/// runApp(
///   ScreenshotServer(
///     child: const MyApp(),
///   ),
/// );
/// ```
///
/// The token is printed to console on start and every hot reload/restart.
/// Then from terminal:
/// ```bash
/// curl -H "Authorization: Bearer <token>" \
///   http://localhost:8080/screenshot --output screenshot.png
/// ```
library;

export 'src/screenshot_server.dart';
export 'src/screenshot_controller.dart';
