import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:present_app/models/user_model.dart';
import 'package:present_app/providers/auth_provider.dart';
import 'package:present_app/providers/conversation_list_provider.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/tts_service.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSpeechToText extends SpeechToText {
  MockSpeechToText() : super.withMethodChannel();

  bool initAvailable = true;
  void Function(String)? customStatusListener;
  void Function(SpeechRecognitionError)? customErrorListener;
  void Function(SpeechRecognitionResult)? resultListener;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
    dynamic debugLogging,
    List<dynamic>? options,
    Duration? finalTimeout,
  }) async {
    customErrorListener = onError;
    customStatusListener = onStatus;
    return initAvailable;
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
    resultListener = onResult;
  }

  @override
  Future<void> stop() async {}
}

class MockTtsService extends TtsService {
  bool throwOnSpeak = false;
  String? lastSpoken;

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw Exception('TTS failure');
    lastSpoken = text;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class MockOpenAiService extends OpenAiService {
  String responseText;
  Object? errorToThrow;

  MockOpenAiService({this.responseText = 'Mock AI 응답', this.errorToThrow});

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return responseText;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VoiceChatState Tests', () {
    test('copyWith and isCallActive coverage', () {
      const state = VoiceChatState();
      expect(state.isCallActive, isFalse);

      final now = DateTime.now();
      final updated = state.copyWith(
        status: VoiceChatStatus.recording,
        recognizedText: '말씀 중',
        aiResponse: '답변 중',
        errorMessage: '에러',
        userSpeechTime: now,
        aiResponseTime: now,
      );

      expect(updated.isCallActive, isTrue);
      expect(updated.status, VoiceChatStatus.recording);
      expect(updated.recognizedText, '말씀 중');
      expect(updated.aiResponse, '답변 중');
      expect(updated.errorMessage, '에러');
      expect(updated.userSpeechTime, now);
      expect(updated.aiResponseTime, now);

      final cleared = updated.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);

      final unmodified = updated.copyWith();
      expect(unmodified.status, updated.status);
      expect(unmodified.recognizedText, updated.recognizedText);
    });
  });

  group('AuthNotifier Tests', () {
    test('build returns null when supabase is null', () async {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier())],
      );
      addTearDown(container.dispose);
      final user = await container.read(authProvider.future);
      expect(user, isNull);
    });

    test('loginWithKakaoId sets error when supabase is null', () async {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier())],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      final notifier = container.read(authProvider.notifier);
      await notifier.loginWithKakaoId('k1', '테스터');
      expect(container.read(authProvider).hasError, isTrue);
    });

    test('bypassLoginForTest sets error when supabase is null', () async {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier())],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      final notifier = container.read(authProvider.notifier);
      await notifier.bypassLoginForTest();
      expect(container.read(authProvider).hasError, isTrue);
    });

    test('logout sets null', () async {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier())],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      final notifier = container.read(authProvider.notifier);
      notifier.logout();
      expect(container.read(authProvider).asData?.value, isNull);
    });

    test('loginWithKakaoId succeeds with Supabase client', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 'u100',
            'kakao_id': 'k100',
            'name': '카카오유저',
            'created_at': DateTime.now().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: req,
        );
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabase))],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final notifier = container.read(authProvider.notifier);
      await notifier.loginWithKakaoId('k100', '카카오유저');
      expect(container.read(authProvider).asData?.value?.id, 'u100');
      expect(container.read(authProvider).asData?.value?.name, '카카오유저');
    });

    test('build restores existing session when user is logged in', () async {
      final mockHttp = MockClient((req) async => http.Response('{}', 200));
      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final dummyUser = User(
        id: 'u_logged_in_12345',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(supabaseClient: supabase, initialUser: dummyUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      final user = await container.read(authProvider.future);
      expect(user?.id, 'u_logged_in_12345');
      expect(user?.name, '익명 테스터');
    });

    test('build restores existing session with profile from users table', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 'u_profile_999',
            'kakao_id': 'k999',
            'name': '홍길동',
            'created_at': DateTime.now().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: req,
        );
      });
      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final dummyUser = User(
        id: 'u_profile_999',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(supabaseClient: supabase, initialUser: dummyUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      final user = await container.read(authProvider.future);
      expect(user?.id, 'u_profile_999');
      expect(user?.kakaoId, 'k999');
      expect(user?.name, '홍길동');
    });

    test('logout clears conversationListProvider and localConversations cache', () async {
      final repo = ConversationRepository();
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '대화 내용',
        userTime: DateTime.now(),
        aiText: '응답 내용',
        aiTime: DateTime.now(),
      );
      expect(repo.localConversations.isNotEmpty, isTrue);

      final loggedInUser = UserModel(id: 'u1', name: '테스터', createdAt: DateTime.now());
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _PredefinedAuthNotifier(loggedInUser)),
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              repository: repo,
              ttsService: MockTtsService(),
              speech: MockSpeechToText(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(conversationListProvider, (_, __) {});
      await container.read(authProvider.future);
      await container.read(conversationListProvider.future);

      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.logout();

      final listAfterLogout = await container.read(conversationListProvider.future);
      expect(container.read(authProvider).asData?.value, isNull);
      expect(listAfterLogout, isEmpty);
      expect(repo.localConversations, isEmpty);
    });

    test('bypassLoginForTest updates user and handles failure', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 'u_anon_12345',
            'kakao_id': 'anonymous_u_ano',
            'name': '익명 테스터',
            'created_at': DateTime.now().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: req,
        );
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabase))],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final notifier = container.read(authProvider.notifier);

      final dummyUser = User(
        id: 'u_anon_12345',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      // 1. Success branch
      await notifier.bypassLoginForTest(mockUser: dummyUser);
      expect(container.read(authProvider).asData?.value?.id, 'u_anon_12345');

      // 2. Failure branch (null user in mock)
      final failContainer = ProviderContainer(
        overrides: [authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabase))],
      );
      addTearDown(failContainer.dispose);

      final failMockHttp = MockClient((req) async {
        return http.Response('{"error": "Unauthorized"}', 401, request: req);
      });
      final failSupabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: failMockHttp);
      final failNotifier = AuthNotifier(supabaseClient: failSupabase);
      final c = ProviderContainer(
        overrides: [authProvider.overrideWith(() => failNotifier)],
      );
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      await c.read(authProvider.notifier).bypassLoginForTest();
      expect(c.read(authProvider).hasError, isTrue);
    });
  });

  group('ConversationListNotifier Tests', () {
    test('build and refresh fetch from repository', () async {
      final repo = ConversationRepository();
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '질문',
        userTime: DateTime.now(),
        aiText: '답변',
        aiTime: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier()),
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              repository: repo,
              ttsService: MockTtsService(),
              speech: MockSpeechToText(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(conversationListProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(authProvider.future);
      final list = await container.read(conversationListProvider.future);
      expect(list.isNotEmpty, isTrue);

      await container.read(conversationListProvider.notifier).refresh();
      expect(container.read(conversationListProvider).asData?.value.isNotEmpty, isTrue);

      container.read(conversationListProvider.notifier).forceUpdate([]);
      expect(container.read(conversationListProvider).asData?.value.isEmpty, isTrue);
    });

    test('clear resets state to empty list and clears repository local cache', () async {
      final repo = ConversationRepository();
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '질문',
        userTime: DateTime.now(),
        aiText: '답변',
        aiTime: DateTime.now(),
      );
      expect(repo.localConversations.isNotEmpty, isTrue);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier()),
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              repository: repo,
              ttsService: MockTtsService(),
              speech: MockSpeechToText(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(conversationListProvider, (_, __) {});
      await container.read(authProvider.future);
      final list = await container.read(conversationListProvider.future);
      expect(list.isNotEmpty, isTrue);

      container.read(conversationListProvider.notifier).clear();
      expect(container.read(conversationListProvider).asData?.value, isEmpty);
      expect(repo.localConversations, isEmpty);
    });
  });

  group('VoiceChatNotifier Full Pipeline Tests', () {
    test('toggleRecording handles speech recognition onResult and finishes pipeline', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(responseText: 'AI의 친절한 답변');
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      // 1. 시작 (recording 진입)
      await notifier.toggleRecording();
      expect(notifier.state.status, VoiceChatStatus.recording);

      // 2. 발화 결과 유입
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('안녕하세요 산책 다녀왔어요', null, 1.0)], 2),
      );
      expect(notifier.state.recognizedText, '안녕하세요 산책 다녀왔어요');

      // 3. STT 종료 알림 ('done')
      mockSpeech.customStatusListener?.call('done');

      // AI 파이프라인 처리 대기
      await Future.delayed(const Duration(milliseconds: 900));

      expect(mockTts.lastSpoken, 'AI의 친절한 답변');
      expect(repo.localConversations.first.summary, '안녕하세요 산책 다녀왔어요');

      // 4. 통화 종료
      await notifier.toggleRecording();
      expect(notifier.state.status, VoiceChatStatus.idle);
    });

    test('STT error triggers _stopAndProcessSpeech', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(responseText: '에러 복구 답변');
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('말씀 중 에러 발생', null, 1.0)], 2),
      );

      // STT 에러 발생
      mockSpeech.customErrorListener?.call(SpeechRecognitionError('테스트 에러', true));

      await Future.delayed(const Duration(milliseconds: 900));
      expect(mockTts.lastSpoken, '에러 복구 답변');

      await notifier.toggleRecording();
    });

    test('AI 429 quota error sets specific polite response', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(errorToThrow: Exception('429 Quota Exceeded'));
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('테스트 질문', null, 1.0)], 2),
      );

      mockSpeech.customStatusListener?.call('notListening');
      await Future.delayed(const Duration(milliseconds: 900));

      expect(mockTts.lastSpoken, contains('숨을 고르고 있어요'));

      await notifier.toggleRecording();
    });

    test('AI generic error sets retry response', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(errorToThrow: 'Server 500 error string');
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('500 에러 테스트', null, 1.0)], 2),
      );

      mockSpeech.customStatusListener?.call('done');
      await Future.delayed(const Duration(milliseconds: 900));

      expect(mockTts.lastSpoken, contains('연결이 원활하지 않아요'));

      await notifier.toggleRecording();
    });

    test('TTS speak failure is handled gracefully', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService()..throwOnSpeak = true;
      final mockAi = MockOpenAiService();
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('TTS 실패 테스트', null, 1.0)], 2),
      );

      mockSpeech.customStatusListener?.call('done');
      await Future.delayed(const Duration(milliseconds: 900));

      // Should not throw, should continue
      expect(notifier.state.status, isNot(VoiceChatStatus.idle));
      await notifier.toggleRecording();
    });

    test('STT unavailable emulator fallback runs and typing timer executes', () async {
      final mockSpeech = MockSpeechToText()..initAvailable = false;
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(responseText: '시뮬레이터 응답');
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      expect(notifier.state.status, VoiceChatStatus.recording);

      // Wait for emulator typing timer ticks (700ms * 4 = 2800ms)
      await Future.delayed(const Duration(milliseconds: 3200));

      expect(mockTts.lastSpoken, '시뮬레이터 응답');
      await notifier.toggleRecording();
    });

    test('STT empty userText re-triggers listening turn without AI call', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService();
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [voiceChatProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      // Send empty recognition result
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('   ', null, 1.0)], 2),
      );
      mockSpeech.customStatusListener?.call('done');

      await Future.delayed(const Duration(milliseconds: 200));

      // AI should NOT have been called, TTS should NOT have spoken
      expect(mockTts.lastSpoken, isNull);
      expect(notifier.state.status, VoiceChatStatus.recording);

      await notifier.toggleRecording();
    });

    test('Multiple turns pass conversation history and conversationRepositoryProvider works', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(responseText: '두 번째 답변');
      final repo = ConversationRepository();

      // Seed first conversation in repository
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '첫 질문',
        userTime: DateTime.now(),
        aiText: '첫 응답',
        aiTime: DateTime.now(),
      );

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier()),
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Verify conversationRepositoryProvider
      expect(container.read(conversationRepositoryProvider), equals(repo));

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('두 번째 질문', null, 1.0)], 2),
      );
      mockSpeech.customStatusListener?.call('done');

      await Future.delayed(const Duration(milliseconds: 900));

      expect(mockTts.lastSpoken, '두 번째 답변');
      expect(repo.localConversations.first.messages.length, 4);

      await notifier.toggleRecording();
    });

    test('STT init exception is caught and handled', () async {
      // Force initialize to throw
      final throwingSpeech = _ThrowingSpeechToText();
      final notifier = VoiceChatNotifier(
        speech: throwingSpeech,
        openAiService: MockOpenAiService(),
        ttsService: MockTtsService(),
      );

      final container = ProviderContainer(
        overrides: [voiceChatProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      final n = container.read(voiceChatProvider.notifier);
      await n.toggleRecording();
      // Should not throw, but fall back gracefully
      await n.toggleRecording();
    });

    test('Default VoiceChatNotifier constructor initializes properly', () {
      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => VoiceChatNotifier(ttsService: MockTtsService(), speech: MockSpeechToText())),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceChatProvider.notifier);
      expect(notifier, isNotNull);
      expect(notifier.repository, isNotNull);
    });

    test('VoiceChatNotifier with authenticated currentUser passes userId', () async {
      final dummyUser = UserModel(
        id: 'user_auth_999',
        kakaoId: 'k999',
        name: '인증유저',
        createdAt: DateTime.now(),
      );

      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService();
      final repo = ConversationRepository();

      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: mockAi,
        ttsService: mockTts,
        repository: repo,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _PredefinedAuthNotifier(dummyUser)),
          voiceChatProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});
      await container.read(authProvider.future);

      final n = container.read(voiceChatProvider.notifier);
      await n.toggleRecording();
      mockSpeech.resultListener?.call(
        SpeechRecognitionResult([SpeechRecognitionWords('유저 ID 테스트', null, 1.0)], 2),
      );
      mockSpeech.customStatusListener?.call('done');

      await Future.delayed(const Duration(milliseconds: 900));

      expect(repo.localConversations.first.userId, 'user_auth_999');
      await n.toggleRecording();
    });

    test('Emulator typing timer cancels when status changes away from recording', () async {
      final mockSpeech = MockSpeechToText()..initAvailable = false;
      final notifier = VoiceChatNotifier(
        speech: mockSpeech,
        openAiService: MockOpenAiService(),
        ttsService: MockTtsService(),
      );

      final container = ProviderContainer(
        overrides: [voiceChatProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container.listen(voiceChatProvider, (_, __) {});

      await notifier.toggleRecording();
      expect(notifier.state.status, VoiceChatStatus.recording);

      // Change status manually to thinking to trigger `timer.cancel(); return;` on next tick
      notifier.state = notifier.state.copyWith(status: VoiceChatStatus.idle);
      await Future.delayed(const Duration(milliseconds: 900));
    });

    test('handleLifecyclePause safely ends active call on background or interrupt', () async {
      final mockSpeech = MockSpeechToText();
      final mockTts = MockTtsService();
      final mockAi = MockOpenAiService(responseText: '답변');
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

      final activeNotifier = container.read(voiceChatProvider.notifier);

      // 1. 활성 통화가 아닐 때 호출해도 아무 문제 없음
      await activeNotifier.handleLifecyclePause();
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);

      // 2. 통화 시작 후 인터럽트 발생
      await activeNotifier.toggleRecording();
      expect(container.read(voiceChatProvider).isCallActive, isTrue);

      // 3. 백그라운드 전환 인터럽트 트리거
      await activeNotifier.handleLifecyclePause();
      expect(container.read(voiceChatProvider).isCallActive, isFalse);
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
    });
  });
}

class _ThrowingSpeechToText extends MockSpeechToText {
  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
    dynamic debugLogging,
    List<dynamic>? options,
    Duration? finalTimeout,
  }) async {
    throw Exception('STT Hardware Error');
  }
}

class _PredefinedAuthNotifier extends AuthNotifier {
  final UserModel _user;
  _PredefinedAuthNotifier(this._user);

  @override
  Future<UserModel?> build() async => _user;
}
