import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:present_app/providers/settings_provider.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/interfaces/i_stt_service.dart';
import 'package:present_app/services/interfaces/i_tts_service.dart';
import 'package:present_app/services/interfaces/i_openai_service.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/ui/persona_bottom_sheet.dart';
import 'package:present_app/services/openai_service.dart';

// Test Mocks
class AuditMockSttService implements ISttService {
  void Function(String)? _onStatus;
  void Function(String)? onResultCallback;
  bool isListeningNow = false;

  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(dynamic) onError,
  }) async {
    _onStatus = onStatus;
    return true;
  }

  @override
  void listen({
    required void Function(String) onResult,
    required Duration pauseFor,
    required void Function() onEmulatorDone,
  }) {
    isListeningNow = true;
    onResultCallback = onResult;
    _onStatus?.call('listening');
  }

  void emitResultAndFinish(String text) {
    onResultCallback?.call(text);
    _onStatus?.call('notListening');
  }

  @override
  Future<void> stop() async {
    isListeningNow = false;
  }

  @override
  void dispose() {
    isListeningNow = false;
  }
}

class AuditMockTtsService implements ITtsService {
  String? lastSpokenText;
  Completer<void>? speakCompleter;
  bool isSpeakingNow = false;

  @override
  Future<void> speak(String text) async {
    lastSpokenText = text;
    isSpeakingNow = true;
    if (speakCompleter != null) {
      await speakCompleter!.future;
    }
    isSpeakingNow = false;
  }

  @override
  Future<void> stop() async {
    isSpeakingNow = false;
    speakCompleter?.complete();
  }

  @override
  void dispose() {
    isSpeakingNow = false;
  }
}

class AuditMockOpenAiService implements IOpenAiService {
  String? lastPersona;
  String? lastParentTitle;
  String? lastUserMessage;
  Completer<String>? replyCompleter;

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    lastUserMessage = userMessage;
    lastPersona = persona;
    lastParentTitle = parentTitle;

    if (replyCompleter != null) {
      return await replyCompleter!.future;
    }

    final title = parentTitle ?? '엄마';
    return '$title, 오늘 산책 다녀오셨어요?';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('🔬 Realtime Persona & Title Concurrency, Interruption & Deadlock Audit', () {
    test('Scenario 1: Mid-Call Title change during STT recording cleanly carries over to AI reply', () async {
      final mockStt = AuditMockSttService();
      final mockTts = AuditMockTtsService();
      final mockAi = AuditMockOpenAiService();
      final mockRepo = ConversationRepository();

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => VoiceChatNotifier(
            sttService: mockStt,
            ttsService: mockTts,
            openAiService: mockAi,
            repository: mockRepo,
          )),
        ],
      );
      addTearDown(container.dispose);
      container.listen(voiceChatProvider, (_, __) {});

      final notifier = container.read(voiceChatProvider.notifier);
      final settingsNotifier = container.read(settingsProvider.notifier);

      // Default title is 엄마
      expect(container.read(settingsProvider).parentTitle, '엄마');

      // 1. User starts talking
      await notifier.toggleRecording();
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.recording);

      // 2. Mid-call: While recording, user changes title from 엄마 to 아빠
      await settingsNotifier.setParentTitle('아빠');
      expect(container.read(settingsProvider).parentTitle, '아빠');
      // Verify active call was NOT terminated by settings change
      expect(container.read(voiceChatProvider).isCallActive, isTrue);

      // 3. User finishes speaking
      mockStt.emitResultAndFinish('오늘 밥 먹었어');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 4. Verify AI reply received '아빠' immediately without deadlock
      expect(mockAi.lastParentTitle, '아빠');
      expect(mockAi.lastUserMessage, '오늘 밥 먹었어');
      expect(mockTts.lastSpokenText, contains('아빠'));
    });

    test('Scenario 2: Mid-Call Title change during AI thinking (in-flight HTTP) does not deadlock or crash', () async {
      final mockStt = AuditMockSttService();
      final mockTts = AuditMockTtsService();
      final mockAi = AuditMockOpenAiService();
      final mockRepo = ConversationRepository();

      // Simulate network delay for AI response
      final aiCompleter = Completer<String>();
      mockAi.replyCompleter = aiCompleter;

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => VoiceChatNotifier(
            sttService: mockStt,
            ttsService: mockTts,
            openAiService: mockAi,
            repository: mockRepo,
          )),
        ],
      );
      addTearDown(container.dispose);
      container.listen(voiceChatProvider, (_, __) {});

      final notifier = container.read(voiceChatProvider.notifier);
      final settingsNotifier = container.read(settingsProvider.notifier);

      await notifier.toggleRecording();
      mockStt.emitResultAndFinish('날씨가 춥네');

      // Allow microtasks to transition to thinking
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.thinking);

      // User changes title while in thinking state
      await settingsNotifier.setParentTitle('아빠');
      expect(container.read(settingsProvider).parentTitle, '아빠');

      // Complete in-flight request
      aiCompleter.complete('엄마, 옷 따뜻하게 챙겨 입으세요.');
      // Wait for TTS speaking and 800ms quiet breathing window to transition back to recording
      await Future<void>.delayed(const Duration(milliseconds: 950));

      // Verify no deadlock, state safely transitioned to speaking and back to recording
      expect(mockTts.lastSpokenText, '엄마, 옷 따뜻하게 챙겨 입으세요.');
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.recording);
      expect(container.read(voiceChatProvider).isCallActive, isTrue);

      // Next speech turn will now immediately pick up 아빠
      mockAi.replyCompleter = null;
      mockStt.emitResultAndFinish('다음에 또 봐');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(mockAi.lastParentTitle, '아빠');
    });

    test('Scenario 3: Mid-Call Title change during TTS speaking does not interrupt ongoing audio', () async {
      final mockStt = AuditMockSttService();
      final mockTts = AuditMockTtsService();
      final mockAi = AuditMockOpenAiService();
      final mockRepo = ConversationRepository();

      // Simulate TTS taking 500ms to speak
      final ttsCompleter = Completer<void>();
      mockTts.speakCompleter = ttsCompleter;

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => VoiceChatNotifier(
            sttService: mockStt,
            ttsService: mockTts,
            openAiService: mockAi,
            repository: mockRepo,
          )),
        ],
      );
      addTearDown(container.dispose);
      container.listen(voiceChatProvider, (_, __) {});

      final notifier = container.read(voiceChatProvider.notifier);
      final settingsNotifier = container.read(settingsProvider.notifier);

      await notifier.toggleRecording();
      mockStt.emitResultAndFinish('안녕');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // State is speaking
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.speaking);

      // User switches title mid-speech
      await settingsNotifier.setParentTitle('아빠');
      expect(container.read(settingsProvider).parentTitle, '아빠');

      // Audio playback continues uninterrupted
      expect(mockTts.isSpeakingNow, isTrue);

      // Finish speaking
      ttsCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Loop resumes back to listening
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.recording);
    });

    test('Scenario 4: High-frequency rapid concurrent title switching (100x burst) maintains consistency', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);

      // Rapidly alternate 100 times concurrently
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        final title = (i % 2 == 0) ? '아빠' : '엄마';
        futures.add(notifier.setParentTitle(title));
      }
      await Future.wait(futures);

      // Ensure state is cleanly either 엄마 or 아빠 and OpenAiService matches
      final currentTitle = container.read(settingsProvider).parentTitle;
      expect(currentTitle == '엄마' || currentTitle == '아빠', isTrue);
      expect(OpenAiService.activeParentTitle, currentTitle);
    });

    testWidgets('Scenario 5: Opening and interacting with PersonaBottomSheet during call does not stop call', (tester) async {
      final mockStt = AuditMockSttService();
      final mockTts = AuditMockTtsService();
      final mockAi = AuditMockOpenAiService();
      final mockRepo = ConversationRepository();

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(() => VoiceChatNotifier(
              sttService: mockStt,
              ttsService: mockTts,
              openAiService: mockAi,
              repository: mockRepo,
            )),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                final voiceState = ref.watch(voiceChatProvider);
                final settings = ref.watch(settingsProvider);
                return Scaffold(
                  appBar: AppBar(
                    title: Text(settings.parentTitle),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => PersonaBottomSheet.show(context),
                      ),
                    ],
                  ),
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => ref.read(voiceChatProvider.notifier).toggleRecording(),
                      child: Text('Status: ${voiceState.status.name}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 1. Start call
      await tester.tap(find.text('Status: idle'));
      await tester.pumpAndSettle();
      expect(find.text('Status: recording'), findsOneWidget);
      expect(capturedRef.read(voiceChatProvider).isCallActive, isTrue);

      // 2. Open PersonaBottomSheet while call is active
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Bottom sheet is visible
      expect(find.text('호칭 및 대화 상대 설정'), findsOneWidget);
      // Call is STILL active in background!
      expect(capturedRef.read(voiceChatProvider).isCallActive, isTrue);

      // 3. Switch title to 아빠 in bottom sheet
      await tester.tap(find.text('아빠'));
      await tester.pumpAndSettle();
      expect(capturedRef.read(settingsProvider).parentTitle, '아빠');

      // 4. Close bottom sheet
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      // Sheet is closed, call is STILL ACTIVE, title is updated to 아빠
      expect(find.text('호칭 및 대화 상대 설정'), findsNothing);
      expect(capturedRef.read(voiceChatProvider).isCallActive, isTrue);
      expect(find.text('아빠'), findsOneWidget);
    });

    testWidgets('Scenario 6: Hardware Audio Interruption while sheet is open cleanly ends call without crashing UI', (tester) async {
      final mockStt = AuditMockSttService();
      final mockTts = AuditMockTtsService();
      final mockAi = AuditMockOpenAiService();
      final mockRepo = ConversationRepository();

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(() => VoiceChatNotifier(
              sttService: mockStt,
              ttsService: mockTts,
              openAiService: mockAi,
              repository: mockRepo,
            )),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                final voiceState = ref.watch(voiceChatProvider);
                return Scaffold(
                  appBar: AppBar(
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => PersonaBottomSheet.show(context),
                      ),
                    ],
                  ),
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => ref.read(voiceChatProvider.notifier).toggleRecording(),
                      child: Text('Status: ${voiceState.status.name}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Start call and open sheet
      await tester.tap(find.text('Status: idle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Simulate incoming phone call or OS audio interrupt
      await capturedRef.read(voiceChatProvider.notifier).handleAudioInterruption(reason: '전화 수신');
      await tester.pumpAndSettle();

      // Call is cleanly stopped, UI is still responsive and does not throw
      expect(capturedRef.read(voiceChatProvider).isCallActive, isFalse);
      expect(capturedRef.read(voiceChatProvider).status, VoiceChatStatus.idle);
      expect(find.text('호칭 및 대화 상대 설정'), findsOneWidget);

      // Can dismiss sheet normally
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('호칭 및 대화 상대 설정'), findsNothing);
    });
  });
}
