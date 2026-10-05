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
import 'package:present_app/ui/persona_bottom_sheet.dart';

class ChaosMockSttService extends SttService {
  void Function(String)? onStatusCallback;
  void Function(dynamic)? onErrorCallback;
  void Function(String)? onResultCallback;
  void Function()? onEmulatorDoneCallback;
  int stopCallCount = 0;

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
    stopCallCount++;
  }
}

class ChaosMockTtsService extends TtsService {
  bool isSpeakingNow = false;
  int speakCallCount = 0;
  int stopCallCount = 0;

  @override
  Future<void> speak(String text) async {
    isSpeakingNow = true;
    speakCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> stop() async {
    isSpeakingNow = false;
    stopCallCount++;
  }
}

class ChaosFlakyOpenAiService implements IOpenAiService {
  int callCount = 0;
  Exception? forcedException;
  Duration delay = const Duration(milliseconds: 10);

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    callCount++;
    if (cancelToken?.isCancelled == true) {
      throw CancelledException('취소됨');
    }

    await Future<void>.delayed(delay);

    if (cancelToken?.isCancelled == true) {
      throw CancelledException('취소됨');
    }

    if (forcedException != null) {
      throw forcedException!;
    }

    return '카오스 테스트 정상 응답입니다.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🔥 Chaos & Adversarial Stress Tests', () {
    late ChaosMockSttService sttService;
    late ChaosMockTtsService ttsService;
    late ChaosFlakyOpenAiService openAiService;
    late ConversationRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sttService = ChaosMockSttService();
      ttsService = ChaosMockTtsService();
      openAiService = ChaosFlakyOpenAiService();
      repository = ConversationRepository(supabaseClient: null);
    });

    test('1. Rapid-fire mic button tapping (20 consecutive rapid toggles)', () async {
      final notifier = VoiceChatNotifier(
        openAiService: openAiService,
        sttService: sttService,
        ttsService: ttsService,
        repository: repository,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);
      container.listen(voiceChatProvider, (_, __) {});

      final activeNotifier = container.read(voiceChatProvider.notifier);

      // 20번의 마이크 토글을 극단적으로 빠르게 연속 호출
      final futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(activeNotifier.toggleRecording());
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future.wait(futures);

      // 예외 없이 완료되며 상태는 유효한 VoiceChatStatus여야 함
      expect(
        [
          VoiceChatStatus.idle,
          VoiceChatStatus.recording,
          VoiceChatStatus.thinking,
          VoiceChatStatus.speaking,
        ],
        contains(container.read(voiceChatProvider).status),
      );
      expect(container.read(voiceChatProvider).errorMessage, isNull);
    });

    test('2. Adversarial network exception fuzzer (Socket drop, 503, Bad JSON)', () async {
      final adversarialExceptions = <Exception>[
        const SocketException('Failed host lookup: api.openai.com'),
        const HttpException('503 Service Temporarily Unavailable'),
        const FormatException('Unexpected character: Malformed JSON payload'),
      ];

      for (final exception in adversarialExceptions) {
        openAiService.forcedException = exception;
        final notifier = VoiceChatNotifier(
          openAiService: openAiService,
          sttService: sttService,
          ttsService: ttsService,
          repository: repository,
        );

        final container = ProviderContainer(
          overrides: [
            voiceChatProvider.overrideWith(() => notifier),
          ],
        );
        addTearDown(container.dispose);
        container.listen(voiceChatProvider, (_, __) {});

        final activeNotifier = container.read(voiceChatProvider.notifier);

        // 녹음 시작 후 발화 전달
        await activeNotifier.toggleRecording();
        sttService.onResultCallback?.call('오늘 날씨 어때?');
        sttService.onEmulatorDoneCallback?.call();

        // 비동기 AI 요청 완료 및 에러 폴백 대기
        int waitAttempts = 0;
        while (container.read(voiceChatProvider).errorMessage == null && waitAttempts < 25) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          waitAttempts++;
        }

        // 비동기 AI 요청 완료 후 시니어 친화적 음성 안내 문구 및 에러 상태 검증
        expect(
          [VoiceChatStatus.speaking, VoiceChatStatus.idle, VoiceChatStatus.recording],
          contains(container.read(voiceChatProvider).status),
        );
        expect(container.read(voiceChatProvider).errorMessage, isNotNull);
        expect(container.read(voiceChatProvider).aiResponse, contains('연결이 원활하지 않아요'));

        // 통화 종료 호출 시 즉시 idle 상태로 안전 복구되는지 검증
        await activeNotifier.toggleRecording();
        expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
      }
    });

    test('3. Concurrent Race Condition: User Cancel during AI streaming + Audio Pause', () async {
      openAiService.delay = const Duration(milliseconds: 250);
      final notifier = VoiceChatNotifier(
        openAiService: openAiService,
        sttService: sttService,
        ttsService: ttsService,
        repository: repository,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);
      container.listen(voiceChatProvider, (_, __) {});

      final activeNotifier = container.read(voiceChatProvider.notifier);

      // AI 요청 시작
      await activeNotifier.toggleRecording();
      sttService.onResultCallback?.call('엄마 사랑해요');
      sttService.onEmulatorDoneCallback?.call();

      // 백그라운드 전환 및 인터럽트 발생
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await activeNotifier.handleLifecyclePause();

      // 요청 종료 대기
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // 크래시 없이 idle 상태 유지 및 TTS 정지 확인
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
      expect(ttsService.isSpeakingNow, isFalse);
    });

    testWidgets('4. Rapid Sheet Mount/Unmount Stress (Persona & Calendar Sheets 20 times)', (tester) async {
      for (int i = 0; i < 20; i++) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: i % 2 == 0
                    ? const PersonaBottomSheet()
                    : const CalendarBottomSheet(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }

      // 위젯 언마운트
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byType(PersonaBottomSheet), findsNothing);
      expect(find.byType(CalendarBottomSheet), findsNothing);
    });

    testWidgets('5. OS Memory Pressure notification resilience', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PersonaBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // OS 메모리 부족 경고 이벤트 발송
      tester.binding.handleMemoryPressure();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    test('6. Offline Pending Queue Disk Persistence & Cold Boot Auto-Restore (Pillar 1)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = ConversationRepository(supabaseClient: null);

      final now = DateTime.now();
      // 오프라인 상태에서 2개의 턴 저장
      await repo1.saveConversationTurn(
        userId: 'cold_boot_user',
        userText: '엄마 밥 먹었어?',
        userTime: now,
        aiText: '응 먹었단다. 너도 챙겨 먹으렴.',
        aiTime: now.add(const Duration(seconds: 1)),
      );
      await repo1.saveConversationTurn(
        userId: 'cold_boot_user',
        userText: '오늘 날씨 어때?',
        userTime: now.add(const Duration(minutes: 5)),
        aiText: '오늘 참 따뜻하고 좋구나.',
        aiTime: now.add(const Duration(minutes: 5, seconds: 1)),
      );

      // repo1의 메모리 큐에 2개 대기 중
      expect(repo1.pendingSyncTurns.length, 2);

      // 앱 강제 종료 및 콜드 부팅 시뮬레이션:
      // 디스크(SharedPreferences)에서 복원하는 새로운 리포지토리 인스턴스 생성
      final repo2 = ConversationRepository(supabaseClient: null);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo2.pendingSyncTurns.length, 2);
      expect(repo2.pendingSyncTurns.first.userText, '엄마 밥 먹었어?');
      expect(repo2.pendingSyncTurns.last.userText, '오늘 날씨 어때?');

      // 캐시 및 디스크 클리어 검증
      repo2.clearLocalCache();
      expect(repo2.pendingSyncTurns, isEmpty);

      // 클리어 후 다시 콜드 부팅 시 완전히 비어있어야 함
      final repo3 = ConversationRepository(supabaseClient: null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo3.pendingSyncTurns, isEmpty);
    });
  });
}
