import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:present_app/ui/senior_error_fallback_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🛡️ Pillar 3: Global Error Boundary & SeniorErrorFallbackWidget Tests', () {
    testWidgets('1. SeniorErrorFallbackWidget renders all senior-friendly elements without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SeniorErrorFallbackWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('화면을 불러오는 중\n잠시 문제가 발생했습니다'), findsOneWidget);
      expect(find.text('대화 내용은 안전하게 보관되어 있습니다.\n앱을 잠시 후 다시 열어주시거나\n화면을 다시 확인해주세요.'), findsOneWidget);
      expect(find.text('화면 다시 시도'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('2. SeniorErrorFallbackWidget renders without overflow at 2.0x font scaling on iPhone SE screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const SeniorErrorFallbackWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('화면 다시 시도'), findsOneWidget);
    });

    testWidgets('3. Tapping retry button triggers navigator pop when canPop is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SeniorErrorFallbackWidget(),
                    ),
                  );
                },
                child: const Text('Go to Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Error'));
      await tester.pumpAndSettle();

      expect(find.text('화면 다시 시도'), findsOneWidget);

      await tester.tap(find.text('화면 다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('Go to Error'), findsOneWidget);
      expect(find.text('화면 다시 시도'), findsNothing);
    });

    testWidgets('4. Tapping retry button when canPop is false handles gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SeniorErrorFallbackWidget(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('화면 다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('화면 다시 시도'), findsOneWidget);
    });

    test('5. setupGlobalErrorHandlers sets handlers and catches errors safely', () {
      setupGlobalErrorHandlers();

      // Verify FlutterError.onError is configured
      expect(FlutterError.onError, isNotNull);
      final details = FlutterErrorDetails(
        exception: Exception('Framework test error'),
        stack: StackTrace.current,
      );
      FlutterError.onError!(details);

      // Verify PlatformDispatcher.instance.onError returns true (handled)
      expect(PlatformDispatcher.instance.onError, isNotNull);
      final handled = PlatformDispatcher.instance.onError!(
        Exception('Async Zone unhandled test error'),
        StackTrace.current,
      );
      expect(handled, isTrue);

      // Verify ErrorWidget.builder returns SeniorErrorFallbackWidget
      final widget = ErrorWidget.builder(details);
      expect(widget, isA<SeniorErrorFallbackWidget>());
    });
  });
}
