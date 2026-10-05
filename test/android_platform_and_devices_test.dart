import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/services/interfaces/i_openai_service.dart';
import 'package:present_app/services/stt_service.dart';
import 'package:present_app/services/tts_service.dart';
import 'package:present_app/ui/calendar_bottom_sheet.dart';
import 'package:present_app/ui/login_screen.dart';
import 'package:present_app/ui/main_screen.dart';
import 'package:present_app/ui/persona_bottom_sheet.dart';
import 'package:present_app/ui/senior_error_fallback_widget.dart';

class AndroidMockSttService extends SttService {
  void Function(String)? onStatusCallback;
  void Function(dynamic)? onErrorCallback;
  void Function(String)? onResultCallback;
  void Function()? onEmulatorDoneCallback;
  int stopCount = 0;

  @override
  Future<bool> initialize({
    Function(dynamic)? onError,
    Function(String)? onStatus,
  }) async {
    onErrorCallback = onError;
    onStatusCallback = onStatus;
    return true;
  }

  @override
  void listen({
    required void Function(String) onResult,
    required Duration pauseFor,
    required void Function() onEmulatorDone,
  }) {
    onResultCallback = onResult;
    onEmulatorDoneCallback = onEmulatorDone;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class AndroidMockTtsService extends TtsService {
  bool isSpeaking = false;
  int stopCount = 0;

  @override
  Future<void> speak(String text) async {
    isSpeaking = true;
  }

  @override
  Future<void> stop() async {
    isSpeaking = false;
    stopCount++;
  }
}

class AndroidMockOpenAiService implements IOpenAiService {
  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    return '안드로이드 정상 응답입니다.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildAndroidTestApp({
    required Widget child,
    double textScale = 1.0,
    Size screenSize = const Size(360, 800),
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          platform: TargetPlatform.android,
        ),
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

  group('🤖 Android & Samsung Galaxy Senior Device Form Factors (2.0x Font Scaling)', () {
    // 대한민국 50~60대 시니어 실제 주력 안드로이드 기기군 해상도 매트릭스
    final samsungGalaxyDevices = <String, Size>{
      '1. Samsung Galaxy A24/A34/A54 (국민 시니어폰 - 360x800)': const Size(360, 800),
      '2. Samsung Galaxy S23/S24 (플래그십 표준 - 393x851)': const Size(393, 851),
      '3. Samsung Galaxy S24 Ultra / Note (대화면 효도폰 - 412x915)': const Size(412, 915),
      '4. Samsung Galaxy Z Fold 커버화면 (초슬림 너비 - 344x882)': const Size(344, 882),
      '5. Samsung Galaxy Z Flip 내부화면 (초장문 22:9 비율 - 360x960)': const Size(360, 960),
      '6. Samsung Galaxy Tab A/S (시니어 태블릿 - 800x1280)': const Size(800, 1280),
    };

    for (final entry in samsungGalaxyDevices.entries) {
      testWidgets('MainScreen renders on ${entry.key} at 2.0x font scaling without overflow', (tester) async {
        tester.view.physicalSize = entry.value * 2.0;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildAndroidTestApp(
            child: const MainScreen(),
            screenSize: entry.value,
            textScale: 2.0,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(MainScreen), findsOneWidget);
      });

      testWidgets('LoginScreen renders on ${entry.key} at 2.0x font scaling without overflow', (tester) async {
        tester.view.physicalSize = entry.value * 2.0;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildAndroidTestApp(
            child: const LoginScreen(showLineLogin: false),
            screenSize: entry.value,
            textScale: 2.0,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    }
  });

  group('🔙 Android Hardware / System Back Button Navigation Tests', () {
    testWidgets('1. Android system back button cleanly dismisses PersonaBottomSheet', (tester) async {
      await tester.pumpWidget(
        buildAndroidTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PersonaBottomSheet.show(context),
              child: const Text('Open Persona'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Persona'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonaBottomSheet), findsOneWidget);

      // 안드로이드 시스템 뒤로가기 키(Back Key / PopRoute) 전송
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PersonaBottomSheet), findsNothing);
      expect(find.text('Open Persona'), findsOneWidget);
    });

    testWidgets('2. Android system back button cleanly dismisses CalendarBottomSheet', (tester) async {
      await tester.pumpWidget(
        buildAndroidTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const CalendarBottomSheet(),
                );
              },
              child: const Text('Open Calendar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Calendar'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarBottomSheet), findsOneWidget);

      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CalendarBottomSheet), findsNothing);
      expect(find.text('Open Calendar'), findsOneWidget);
    });

    testWidgets('3. Android system back button cleanly pops SeniorErrorFallbackWidget', (tester) async {
      await tester.pumpWidget(
        buildAndroidTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SeniorErrorFallbackWidget()),
                );
              },
              child: const Text('Open Error Screen'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Error Screen'));
      await tester.pumpAndSettle();

      expect(find.byType(SeniorErrorFallbackWidget), findsOneWidget);

      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SeniorErrorFallbackWidget), findsNothing);
      expect(find.text('Open Error Screen'), findsOneWidget);
    });
  });

  group('⚡ Android OS Lifecycle & Background Transition Resilience Tests', () {
    test('1. Android OS pause (Phone call / Home button / Split-screen) halts voice turn safely', () async {
      final stt = AndroidMockSttService();
      final tts = AndroidMockTtsService();
      final ai = AndroidMockOpenAiService();
      final repo = ConversationRepository(supabaseClient: null);

      final notifier = VoiceChatNotifier(
        openAiService: ai,
        sttService: stt,
        ttsService: tts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);
      container.listen(voiceChatProvider, (_, __) {});

      final activeNotifier = container.read(voiceChatProvider.notifier);

      // 음성 대화 시작
      await activeNotifier.toggleRecording();
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.recording);

      // 안드로이드 OS의 백그라운드 전환 (AppLifecycleState.paused / onPause)
      await activeNotifier.handleLifecyclePause();

      // 마이크 안전 중단 및 idle 복구 확인
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
      expect(stt.stopCount, greaterThanOrEqualTo(1));
    });
  });

  group('📄 AndroidManifest & Android 11+ Package Visibility Integrity Tests', () {
    test('1. AndroidManifest.xml contains essential permissions and Android 11+ queries', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // 1. 필수 권한 검증
      expect(content, contains('android.permission.RECORD_AUDIO'));
      expect(content, contains('android.permission.INTERNET'));
      expect(content, contains('android.permission.MODIFY_AUDIO_SETTINGS'));
      expect(content, contains('android.permission.BLUETOOTH_CONNECT'));

      // 2. 안드로이드 11+ 패키지 가시성 (<queries>) 검증
      expect(content, contains('<queries>'));
      expect(content, contains('android.speech.RecognitionService'),
          reason: 'Android 11+ requires RecognitionService in queries for Google Speech STT');
      expect(content, contains('android.intent.action.TTS_SERVICE'),
          reason: 'Android 11+ requires TTS_SERVICE in queries for Text-to-Speech engines');

      // 3. 카카오 로그인 리다이렉트 액티비티 검증
      expect(content, contains('com.kakao.sdk.flutter.AuthCodeCustomTabsActivity'));
      expect(content, contains('kakao\${KAKAO_NATIVE_APP_KEY}'));
    });

    test('2. android/app/build.gradle.kts defines KAKAO_NATIVE_APP_KEY manifestPlaceholder', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue, reason: 'build.gradle.kts must exist');

      final content = gradleFile.readAsStringSync();
      expect(content, contains('manifestPlaceholders["KAKAO_NATIVE_APP_KEY"]'));
      expect(content, contains('1f20e3601cb54e69eb1fd00f0f68c43b'));
    });
  });
}
