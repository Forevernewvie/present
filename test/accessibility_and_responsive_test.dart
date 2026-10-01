import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:present_app/ui/login_screen.dart';
import 'package:present_app/ui/main_screen.dart';
import 'package:present_app/ui/persona_bottom_sheet.dart';
import 'package:present_app/ui/calendar_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({
    required Widget child,
    double textScale = 2.0,
    Size screenSize = const Size(390, 844),
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('🧓 Senior 2.0x Font Scaling & A11y Accessibility Tests', () {
    testWidgets('1. MainScreen renders without overflow at 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const MainScreen(),
          textScale: 2.0,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('2. PersonaBottomSheet renders without overflow at 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const PersonaBottomSheet(),
          textScale: 2.0,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PersonaBottomSheet), findsOneWidget);
    });

    testWidgets('3. CalendarBottomSheet renders without overflow at 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const CalendarBottomSheet(),
          textScale: 2.0,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CalendarBottomSheet), findsOneWidget);
    });

    testWidgets('4. LoginScreen renders without overflow at 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const LoginScreen(showLineLogin: false),
          textScale: 2.0,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('📱 Multi-Device Screen Resolution Bounds Tests', () {
    final deviceResolutions = <String, Size>{
      'Small iOS (iPhone SE 1st gen - 320x568)': const Size(320, 568),
      'Standard iOS (iPhone 13 - 390x844)': const Size(390, 844),
      'Large iOS (iPhone 15 Pro Max - 430x932)': const Size(430, 932),
      'Tablet iOS (iPad - 810x1080)': const Size(810, 1080),
      'Samsung Galaxy A24/A34/A54 (국민 시니어폰 - 360x800)': const Size(360, 800),
      'Samsung Galaxy S23/S24 (플래그십 - 393x851)': const Size(393, 851),
      'Samsung Galaxy S24 Ultra (대화면 - 412x915)': const Size(412, 915),
      'Samsung Galaxy Z Fold 커버 (초슬림 너비 - 344x882)': const Size(344, 882),
      'Samsung Galaxy Z Flip 내부 (22:9 초장문 - 360x960)': const Size(360, 960),
      'Samsung Galaxy Tab A/S (시니어 안드로이드 태블릿 - 800x1280)': const Size(800, 1280),
    };

    for (final entry in deviceResolutions.entries) {
      testWidgets('Renders MainScreen on ${entry.key} without overflow', (tester) async {
        tester.view.physicalSize = entry.value * 2.0;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestApp(
            child: const MainScreen(),
            screenSize: entry.value,
            textScale: 1.0,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
