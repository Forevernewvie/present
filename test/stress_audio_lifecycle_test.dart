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
import 'package:shared_preferences/shared_preferences.dart';

class MockSpeechToTextForStress extends SpeechToText {
  MockSpeechToTextForStress() : super.withMethodChannel();

  bool isInitialized = false;
  bool isListeningNow = false;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
    dynamic debugLogging,
    List<dynamic>? options,
    Duration? finalTimeout,
  }) async {
    isInitialized = true;
    return true;
  }

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
  }) async {
    isListeningNow = true;
  }

  @override
  Future<void> stop() async {
    isListeningNow = false;
  }
}

class MockTtsServiceForStress extends TtsService {
  bool isSpeakingNow = false;

  @override
  Future<void> speak(String text) async {
    isSpeakingNow = true;
    await Future.delayed(const Duration(milliseconds: 50));
    isSpeakingNow = false;
  }

  @override
  Future<void> stop() async {
    isSpeakingNow = false;
  }

  @override
  void dispose() {
    isSpeakingNow = false;
  }
}

class MockOpenAiServiceForStress extends OpenAiService {
  final Duration delay;
  final bool shouldFail;

  MockOpenAiServiceForStress({this.delay = const Duration(milliseconds: 50), this.shouldFail = false});

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    await Future.delayed(delay);
    if (shouldFail) {
      throw Exception('LLM Failure 500');
    }
    return '스트레스 테스트 응답: $userMessage';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Vulnerability #1: Audio Session & Hardware Lifecycle Stress Tests', () {
    test('1. Rapid mic toggle spam (50 consecutive toggles) maintains state integrity', () async {
      final mockSpeech = MockSpeechToTextForStress();
      final mockTts = MockTtsServiceForStress();
      final mockAi = MockOpenAiServiceForStress();
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

      // 50회 연속 토글 스트레스 실행
      for (int i = 0; i < 50; i++) {
        await activeNotifier.toggleRecording();
      }

      // 최종 상태가 idle이거나 recording 중 하나여야 하며, 에러 없이 안정적이어야 함
      final finalState = container.read(voiceChatProvider);
      expect(
        finalState.status == VoiceChatStatus.idle || finalState.status == VoiceChatStatus.recording,
        isTrue,
      );
      expect(finalState.errorMessage, isNull);
    });

    test('2. Lifecycle pause during recording immediately halts audio and cleans state', () async {
      final mockSpeech = MockSpeechToTextForStress();
      final mockTts = MockTtsServiceForStress();
      final mockAi = MockOpenAiServiceForStress();
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

      // 통화 시작
      await activeNotifier.toggleRecording();
      expect(container.read(voiceChatProvider).isCallActive, isTrue);

      // 즉각 라이프사이클 인터럽트 발생
      await activeNotifier.handleLifecyclePause();

      // 검증: 통화 즉각 해제 및 idle 전이
      expect(container.read(voiceChatProvider).isCallActive, isFalse);
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
      expect(mockSpeech.isListeningNow, isFalse);
    });

    test('3. Repeated lifecycle pause/resume cycles (20 times) do not cause deadlock', () async {
      final mockSpeech = MockSpeechToTextForStress();
      final mockTts = MockTtsServiceForStress();
      final mockAi = MockOpenAiServiceForStress();
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

      for (int i = 0; i < 20; i++) {
        await activeNotifier.toggleRecording(); // 시작
        await activeNotifier.handleLifecyclePause(); // 인터럽트
        expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
      }
    });

    test('4. Empty speech input repeated 30 times does not overflow or crash', () async {
      final mockSpeech = MockSpeechToTextForStress();
      final mockTts = MockTtsServiceForStress();
      final mockAi = MockOpenAiServiceForStress();
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
      await activeNotifier.toggleRecording();

      // 빈 텍스트 상태로 강제 전이 시뮬레이션
      for (int i = 0; i < 30; i++) {
        activeNotifier.state = activeNotifier.state.copyWith(
          status: VoiceChatStatus.recording,
          recognizedText: '',
        );
      }

      expect(container.read(voiceChatProvider).errorMessage, isNull);
    });
  });
}
