# advanced_screenshot

A Flutter package that provides remote screenshot capture via a built-in debug HTTP server. Take screenshots of your running Flutter app from any terminal or CI script — works on all platforms.

## Features

- 📸 **Remote screenshot capture** via HTTP API
- 🔒 **Token authentication** — secure access control
- ⚡ **Rate limiting** — 1 screenshot per second by default
- 🔒 **Debug-only by default** — safe for development
- 🌐 **Cross-platform** — works on iOS, Android, macOS, Windows, Linux
- 🎯 **Zero configuration** — just wrap your app and go
- 🔧 **Flexible** — customize port, token, and more

## Usage

Wrap your app's root widget with `ScreenshotServer`:

```dart
import 'package:advanced_screenshot/advanced_screenshot.dart';

void main() {
  runApp(
    ScreenshotServer(
      child: const MyApp(),
    ),
  );
}
```

On app start, the server prints connection info to console:

```
┌────────────────────────────────────────────────┐
│ 📸 Advanced Screenshot Server                  │
│                                                │
│ URL:   http://127.0.0.1:8080                   │
│ Token: 652e9357-84b4-48fa-a3b1-577a4a71fa30    │
└────────────────────────────────────────────────┘
```

Then capture screenshots from your terminal:

```bash
# Take a screenshot
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/screenshot --output screenshot.png

# Higher resolution (2x pixel ratio)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/screenshot?pixelRatio=2.0 --output screenshot@2x.png

# Health check
curl http://localhost:8080/ping
```

### Configuration

```dart
ScreenshotServer(
  port: 8080,                                // Server port
  token: 'your-secret-token',                // Auth token (auto-generated if not provided)
  maxRequestsPerSecond: 1,                   // Rate limit
  bindAddress: InternetAddress.loopbackIPv4, // Bind to localhost only
  child: const MyApp(),
)
```

### Android device via USB

```bash
adb forward tcp:8080 tcp:8080
curl http://localhost:8080/screenshot --output screenshot.png
```

### iOS device

Connect to the device's IP address on the same Wi-Fi network:

```bash
curl http://<device-ip>:8080/screenshot --output screenshot.png
```

## API

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/screenshot` | Capture and return PNG screenshot |
| GET | `/screenshot?pixelRatio=2.0` | Capture with custom pixel ratio |
| GET | `/ping` | Health check, returns `pong` |

### ScreenshotController

Can be used standalone without the server:

```dart
final controller = ScreenshotController();

RepaintBoundary(
  key: controller.boundaryKey,
  child: MyApp(),
);

final byteData = await controller.capture(pixelRatio: 2.0);
```
