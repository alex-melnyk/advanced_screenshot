import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'screenshot_controller.dart';
import 'screenshot_security_banner.dart';

/// A widget that wraps its [child] with a [RepaintBoundary] and starts
/// a lightweight HTTP server for remote screenshot capture.
///
/// The server listens on the specified [port] and responds to:
/// - `GET /screenshot` — returns a PNG screenshot of the app
/// - `GET /screenshot?pixelRatio=2.0` — returns a higher resolution screenshot
/// - `GET /ping` — returns `pong` (health check)
///
/// ## Security
///
/// By default the server **only starts in debug mode** (`kDebugMode`).
/// In release builds the widget renders just the [child] without starting
/// any server.
///
/// To force-enable in release mode, set [forceEnable] to `true`.
/// This will display a prominent security warning banner on the UI and
/// print a warning to the console. This is intended **only** for internal
/// testing builds and should **never** be shipped to end users.
///
/// Set [enabled] to `false` to disable the server entirely regardless
/// of build mode.
///
/// ## Example
///
/// ```dart
/// runApp(
///   ScreenshotServer(
///     child: const MyApp(),
///   ),
/// );
/// ```
///
/// On app start (and every hot reload/restart), the server prints
/// connection info with the token to the console:
///
/// ```
/// ┌──────────────────────────────────────────────────────────────┐
/// │  📸 Advanced Screenshot Server                              │
/// │                                                            │
/// │  URL:   http://127.0.0.1:8080                              │
/// │  Token: aBcDeFgHiJkLmNoPqRsTuVwXyZ012345                  │
/// └──────────────────────────────────────────────────────────────┘
/// ```
///
/// Then from terminal:
/// ```bash
/// curl -H "Authorization: Bearer <token>" \
///   http://localhost:8080/screenshot --output screenshot.png
/// ```
///
/// For Android devices connected via USB, forward the port first:
/// ```bash
/// adb forward tcp:8080 tcp:8080
/// curl http://localhost:8080/screenshot --output screenshot.png
/// ```
class ScreenshotServer extends StatefulWidget {
  /// Creates a [ScreenshotServer] widget.
  ///
  /// [port] is the TCP port the HTTP server will listen on.
  /// Defaults to 8080.
  ///
  /// [enabled] controls whether the server should start at all.
  /// Defaults to `true`. Set to `false` to disable even in debug mode.
  ///
  /// [forceEnable] allows the server to run in release mode.
  /// When `true` in a release build, a security warning banner is shown
  /// on the UI and a warning is printed to the console.
  ///
  /// [child] is the widget tree to render and capture.
  ScreenshotServer({
    super.key,
    this.port = 8080,
    this.enabled = true,
    this.forceEnable = false,
    this.bindAddress,
    String? token,
    this.maxRequestsPerSecond = 1,
    required this.child,
  }) : token = token ?? const Uuid().v4();

  /// The TCP port for the HTTP server. Defaults to 8080.
  final int port;

  /// Whether the server is enabled. Defaults to `true`.
  ///
  /// When `false`, the server will not start regardless of build mode.
  final bool enabled;

  /// Whether to force-enable the server in release mode.
  ///
  /// When `true` and the app is running in release mode, the server will
  /// start but a security warning banner will be displayed on the UI
  /// and a warning printed to the console.
  ///
  /// **WARNING:** Do not ship builds with this set to `true` to end users.
  final bool forceEnable;

  /// The address to bind the server to.
  ///
  /// Defaults to [InternetAddress.loopbackIPv4] (`127.0.0.1`) which only
  /// allows connections from the same machine.
  ///
  /// Use [InternetAddress.anyIPv4] (`0.0.0.0`) to allow connections from
  /// other devices on the network (e.g. from host to emulator).
  final InternetAddress? bindAddress;

  /// Authentication token for the server.
  ///
  /// Every request must include a matching `Authorization` header
  /// (`Bearer <token>`) or `?token=<token>` query parameter.
  /// Requests without a valid token receive a `401 Unauthorized` response.
  ///
  /// If not provided, a random UUID v4 token is generated automatically
  /// and printed to the console on server start.
  final String token;

  /// Maximum number of screenshot requests per second. Defaults to 1.
  ///
  /// Requests exceeding this limit receive a `429 Too Many Requests`
  /// response. Set to `0` to disable rate limiting.
  final int maxRequestsPerSecond;

  /// The widget tree to render and capture screenshots of.
  final Widget child;

  @override
  State<ScreenshotServer> createState() => _ScreenshotServerState();
}

class _ScreenshotServerState extends State<ScreenshotServer> {
  final _controller = ScreenshotController();
  HttpServer? _server;
  final _requestTimestamps = <DateTime>[];

  /// Whether the server should be active based on current configuration.
  bool get _shouldBeActive {
    if (!widget.enabled) return false;
    if (kDebugMode) return true;
    return widget.forceEnable;
  }

  /// Whether we are running in forced release mode.
  bool get _isForcedRelease => !kDebugMode && widget.forceEnable;

  @override
  void initState() {
    super.initState();

    if (_shouldBeActive) {
      if (_isForcedRelease) {
        _printSecurityWarning();
      }
      _startServer();
    }
  }

  @override
  void didUpdateWidget(covariant ScreenshotServer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasActive = oldWidget.enabled && (kDebugMode || oldWidget.forceEnable);
    final isActive = _shouldBeActive;

    if (wasActive && !isActive) {
      _stopServer();
    } else if (!wasActive && isActive) {
      if (_isForcedRelease) {
        _printSecurityWarning();
      }
      _startServer();
    } else if (isActive && oldWidget.port != widget.port) {
      _stopServer().then((_) => _startServer());
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    if (_server != null) {
      _printServerInfo();
    }
  }

  @override
  void dispose() {
    _stopServer();
    super.dispose();
  }

  void _printSecurityWarning() {
    // ignore: avoid_print
    debugPrint(
      '\n'
      '╔══════════════════════════════════════════════════════════════╗\n'
      '║  ⚠️  ADVANCED SCREENSHOT: SECURITY WARNING                  ║\n'
      '║                                                            ║\n'
      '║  Screenshot server is running in RELEASE mode!             ║\n'
      '║  Port: ${widget.port.toString().padRight(53)}║\n'
      '║                                                            ║\n'
      '║  Anyone on the network can capture screenshots of the app. ║\n'
      '║  Do NOT ship this build to end users.                      ║\n'
      '╚══════════════════════════════════════════════════════════════╝\n',
    );
  }

  Future<void> _startServer() async {
    try {
      final address = widget.bindAddress ?? InternetAddress.loopbackIPv4;

      _server = await HttpServer.bind(address, widget.port);

      _server!.listen(_handleRequest);
      _printServerInfo(address);
    } catch (e) {
      debugPrint('[AdvancedScreenshot] Failed to start server: $e');
    }
  }

  Future<void> _stopServer() async {
    await _server?.close(force: true);
    _server = null;
    debugPrint('[AdvancedScreenshot] Server stopped');
  }

  /// Prints server connection info to the console.
  void _printServerInfo([InternetAddress? address]) {
    address ??= widget.bindAddress ?? InternetAddress.loopbackIPv4;

    final url = 'http://${address.address}:${widget.port}';

    final title = '\u{1F4F8} Advanced Screenshot Server';
    final urlLine = 'URL:   $url';
    final tokenLine = 'Token: ${widget.token}';
    final lines = [title, '', urlLine, tokenLine];

    final contentWidth = lines.fold<int>(
      0,
      (max, line) => line.length > max ? line.length : max,
    );
    final boxWidth = contentWidth + 4; // 2 padding + 2 borders

    final horizontal = '\u2500' * (boxWidth - 2);
    final top = '\u250C$horizontal\u2510';
    final bottom = '\u2514$horizontal\u2518';
    final body = lines
        .map((line) => '\u2502 ${line.padRight(contentWidth)} \u2502')
        .join('\n');

    // ignore: avoid_print
    debugPrint('\n$top\n$body\n$bottom\n');
  }

  /// Checks if the request has a valid authentication token.
  bool _isAuthenticated(HttpRequest request) {
    final authHeader = request.headers.value('authorization');
    if (authHeader != null && authHeader == 'Bearer ${widget.token}') {
      return true;
    }

    final queryToken = request.uri.queryParameters['token'];
    if (queryToken == widget.token) {
      return true;
    }

    return false;
  }

  /// Checks if the request is within the rate limit.
  ///
  /// Returns `true` if allowed, `false` if rate limited (and sends 429).
  bool _checkRateLimit(HttpRequest request) {
    if (widget.maxRequestsPerSecond <= 0) return true;

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(seconds: 1));

    _requestTimestamps.removeWhere((ts) => ts.isBefore(windowStart));

    if (_requestTimestamps.length >= widget.maxRequestsPerSecond) {
      request.response
        ..statusCode = HttpStatus.tooManyRequests
        ..headers.contentType = ContentType.text
        ..write('Rate limit exceeded. Max ${widget.maxRequestsPerSecond} '
            'requests per second.');
      request.response.close();
      debugPrint('[AdvancedScreenshot] Rate limit exceeded');
      return false;
    }

    _requestTimestamps.add(now);
    return true;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;

    // CORS headers for browser access
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET');

    // Token authentication
    if (!_isAuthenticated(request)) {
      response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.text
        ..write('Unauthorized. Provide token via '
            'Authorization: Bearer <token> header '
            'or ?token=<token> query parameter.');
      await response.close();
      return;
    }

    try {
      switch (path) {
        case '/screenshot':
          if (!_checkRateLimit(request)) return;
          await _handleScreenshot(request);
        case '/ping':
          response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write('pong');
        default:
          response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.text
            ..write('Not found. Available endpoints: /screenshot, /ping');
      }
    } catch (e) {
      response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.text
        ..write('Error: $e');
    } finally {
      await response.close();
    }
  }

  Future<void> _handleScreenshot(HttpRequest request) async {
    final pixelRatioParam = request.uri.queryParameters['pixelRatio'];
    final pixelRatio = double.tryParse(pixelRatioParam ?? '') ?? 1.0;

    final pngBytes = await _controller.capture(pixelRatio: pixelRatio);

    if (pngBytes == null) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.text
        ..write('Widget tree not ready for capture');
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('image', 'png')
      ..headers.add('Content-Length', pngBytes.length.toString())
      ..add(pngBytes);

    debugPrint(
      '[AdvancedScreenshot] Screenshot captured '
      '(${pngBytes.length} bytes, pixelRatio: $pixelRatio)',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldBeActive) {
      return widget.child;
    }

    Widget child = RepaintBoundary(
      key: _controller.boundaryKey,
      child: widget.child,
    );

    if (_isForcedRelease) {
      child = Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ScreenshotSecurityBanner(),
            ),
          ],
        ),
      );
    }

    return child;
  }
}
