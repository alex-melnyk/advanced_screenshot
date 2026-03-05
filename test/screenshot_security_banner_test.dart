import 'package:advanced_screenshot/src/screenshot_security_banner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenshotSecurityBanner', () {
    testWidgets('renders warning text', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScreenshotSecurityBanner(),
        ),
      );

      expect(
        find.text('\u26A0 Screenshot server is active (RELEASE MODE)'),
        findsOneWidget,
      );
    });

    testWidgets('has red background', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScreenshotSecurityBanner(),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.color, equals(const Color(0xFFD32F2F)));
    });

    testWidgets('wraps in SafeArea', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScreenshotSecurityBanner(),
        ),
      );

      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}
