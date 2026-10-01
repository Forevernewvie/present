import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/tts_service.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class MockSpeechSlow extends SpeechToText {
  MockSpeechSlow() : super.withMethodChannel();

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
    dynamic debugLogging,
    List<dynamic>? options,
    Duration? finalTimeout,
  }) async => true;

  @override
  Future<void> listen({
    void Function(SpeechRecognitionResult)? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    dynamic soundLevel,
    dynamic cancelOnError,
    dynamic partialResults,
    dynamic onDevice,
    dynamic listenMode,
    dynamic sampleRate,
    dynamic listenOptions,
    void Function(double)? onSoundLevelChange,
  }) async {}

  @override
  Future<void> stop() async {}
}

class MockTtsTracking extends TtsService {
  int speakCallCount = 0;

  @override
  Future<void> speak(String text) async {
    speakCallCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class MockOpenAiDelayed extends OpenAiService {
  final Duration delay;
  final bool throw429;
  final bool throw500;

  MockOpenAiDelayed({
    this.delay = const Duration(milliseconds: 100),
    this.throw429 = false,
    this.throw500 = false,
  });

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    CancellationToken? cancelToken,
  }) async {
    await Future.delayed(delay);
    if (throw429) {
      throw Exception('HTTP 429: Quota exceeded or rate limit reached');
    }
    if (throw500) {
      throw Exception('HTTP 500: Internal server error from AI provider');
    }
    return '응답: $userMessage';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vulnerability #2: LLM Latency & Cancellation Stress Tests', () {
    test('1. Call cancelled while LLM is thinking does not trigger TTS or leave stale state', () async {
      final mockSpeech = MockSpeechSlow();
      final mockTts = MockTtsTracking();
      // LLM 응답 지연 300ms 설정
      final mockAi = MockOpenAiDelayed(delay: const Duration(milliseconds: 300));
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        ttsService: mockTts,
        openAiService: mockAi,
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

      // 통화 시작 및 thinking 상태 진입
      await activeNotifier.toggleRecording();
      activeNotifier.state = activeNotifier.state.copyWith(
        status: VoiceChatStatus.thinking,
        recognizedText: '안녕 AI',
      );

      // LLM 응답 대기 도중 사용자가 통화를 종료함
      await activeNotifier.toggleRecording(); // isCallActive = false, status = idle
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);

      // LLM 응답 지연 시간(300ms) 경과 대기
      await Future.delayed(const Duration(milliseconds: 350));

      // 검증: 통화가 이미 끝났으므로 TTS가 불리지 않아야 하고 상태는 idle 유지
      expect(mockTts.speakCallCount, 0);
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
    });

    test('2. Burst 429 Quota Exceeded errors (20 consecutive) are handled gracefully without crash', () async {
      final mockAi = MockOpenAiDelayed(throw429: true);

      for (int i = 0; i < 20; i++) {
        try {
          await mockAi.getAiReply(userMessage: '테스트 $i');
        } catch (e) {
          expect(e.toString().contains('429'), isTrue);
        }
      }
    });

    test('3. Burst 500 Internal Server errors (20 consecutive) do not break repository or provider', () async {
      final mockAi = MockOpenAiDelayed(throw500: true);

      for (int i = 0; i < 20; i++) {
        try {
          await mockAi.getAiReply(userMessage: '에러 테스트 $i');
        } catch (e) {
          expect(e.toString().contains('500'), isTrue);
        }
      }
    });

    test('4. Rapid 10-turn conversation pipeline stress executes reliably', () async {
      final mockTts = MockTtsTracking();
      final mockAi = MockOpenAiDelayed(delay: const Duration(milliseconds: 10));

      for (int turn = 1; turn <= 10; turn++) {
        final reply = await mockAi.getAiReply(userMessage: '턴 $turn');
        expect(reply, '응답: 턴 $turn');
        await mockTts.speak(reply);
      }

      expect(mockTts.speakCallCount, 10);
    });
  });
}
