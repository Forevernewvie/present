import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:present_app/providers/auth_provider.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/stt_service.dart';
import 'package:present_app/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSttServiceForEdgeCases extends SttService {
  @override
  Future<bool> initialize({
    required Function(String) onStatus,
    required Function(dynamic) onError,
  }) async => true;

  @override
  void listen({
    required void Function(String) onResult,
    required Duration pauseFor,
    required void Function() onEmulatorDone,
  }) {
    onResult('인식된 음성 발화');
  }

  @override
  Future<void> stop() async {}
}

class ThrowingInitSttService extends SttService {
  @override
  Future<bool> initialize({
    required Function(String) onStatus,
    required Function(dynamic) onError,
  }) async {
    throw Exception('STT 하드웨어 고장');
  }

  @override
  void listen({
    required void Function(String) onResult,
    required Duration pauseFor,
    required void Function() onEmulatorDone,
  }) {}

  @override
  Future<void> stop() async {}
}

class MockTtsServiceForEdgeCases extends TtsService {
  @override
  Future<void> speak(String text, {Function()? onComplete}) async {
    onComplete?.call();
  }

  @override
  Future<void> stop() async {}
}

class ThrowingCancelledAiService extends OpenAiService {
  ThrowingCancelledAiService() : super(apiKey: 'sk-test');

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    throw CancelledException('취소되었습니다');
  }
}

class ThrowingClearCacheRepo extends ConversationRepository {
  @override
  void clearLocalCache() {
    throw Exception('캐시 초기화 중 오류');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OpenAiService Edge Cases Tests', () {
    test('history with Map and primitive String', () async {
      final mockHttp = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, greaterThanOrEqualTo(3));
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '역사 포함 답변 완료'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiService(client: mockHttp, apiKey: 'sk-test');
      final reply = await service.getAiReply(
        userMessage: '새로운 질문',
        history: [
          {'sender': 'user', 'content': '이전 질문 1'},
          {'isUser': false, 'content': '이전 답변 1'},
          '문자열 원시 히스토리',
        ],
      );

      expect(reply, '역사 포함 답변 완료');
    });

    test('pre-cancelled token throws CancelledException immediately', () async {
      final token = CancellationToken();
      token.cancel();

      final service = OpenAiService(apiKey: 'sk-test');
      expect(
        () => service.getAiReply(userMessage: '질문', cancelToken: token),
        throwsA(isA<CancelledException>()),
      );
    });

    test('token cancelled during ongoing request throws CancelledException', () async {
      final token = CancellationToken();
      final mockHttp = MockClient((req) async {
        token.cancel();
        throw CancelledException('취소됨');
      });

      final service = OpenAiService(client: mockHttp, apiKey: 'sk-test');
      expect(
        () => service.getAiReply(userMessage: '질문', cancelToken: token),
        throwsA(isA<CancelledException>()),
      );
    });

    test('default client cancels during request triggers onCancel and finally cleanup', () async {
      final token = CancellationToken();
      final service = OpenAiService(apiKey: 'sk-test');

      // Schedule cancel to fire right after registration
      Timer(const Duration(milliseconds: 1), () => token.cancel());

      try {
        await service.getAiReply(userMessage: '질문', cancelToken: token);
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('HTTP 429 quota exceeded error throws specific message', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'You exceeded your current quota'}
          }),
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiService(client: mockHttp, apiKey: 'sk-test');
      expect(
        () => service.getAiReply(userMessage: '질문'),
        throwsA(predicate((e) => e.toString().contains('할당량 초과(429)'))),
      );
    });

    test('HTTP 500 server error throws specific message', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Internal Server Error'}
          }),
          500,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiService(client: mockHttp, apiKey: 'sk-test');
      expect(
        () => service.getAiReply(userMessage: '질문'),
        throwsA(predicate((e) => e.toString().contains('서버 에러(5xx)'))),
      );
    });
  });

  group('ConversationRepository Edge Cases Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveConversationTurn on TimeoutException adds to pending sync queue', () async {
      final mockHttp = MockClient((req) async {
        throw TimeoutException('Supabase connection timeout');
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      await repo.saveConversationTurn(
        userId: 'u_timeout',
        userText: '타임아웃 발화',
        userTime: DateTime.now(),
        aiText: '타임아웃 응답',
        aiTime: DateTime.now(),
      );

      expect(repo.pendingSyncTurns.length, 1);
      expect(repo.pendingSyncTurns.first.userText, '타임아웃 발화');
    });

    test('syncPendingTurns syncs with existing conversation room and new room', () async {
      int requestCount = 0;
      bool failSave = true;

      final mockHttp = MockClient((req) async {
        if (failSave) {
          throw Exception('네트워크 저장 실패로 대기 큐 인입');
        }

        final path = req.url.path;
        final method = req.method;

        if (path.contains('conversations') && method == 'GET') {
          requestCount++;
          if (requestCount == 1) {
            // First turn finds existing room
            return http.Response(
              jsonEncode({'id': 'existing_conv_123'}),
              200,
              headers: {'content-type': 'application/json'},
              request: req,
            );
          } else {
            // Second turn has no existing room
            return http.Response('null', 200, headers: {'content-type': 'application/json'}, request: req);
          }
        } else if (path.contains('conversations') && method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'new_conv_456',
              'user_id': 'u_sync',
              'date': '2026-09-11',
              'summary': '동기화 생성 요약',
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        } else if (path.contains('messages') && method == 'POST') {
          return http.Response(jsonEncode([]), 201, headers: {'content-type': 'application/json'}, request: req);
        }
        return http.Response('Not Found', 404, request: req);
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      // Populate pendingSyncTurns via saveConversationTurn
      await repo.saveConversationTurn(
        userId: 'u_sync',
        userText: '짧은 발화',
        userTime: DateTime.now(),
        aiText: '답변 1',
        aiTime: DateTime.now(),
      );
      await repo.saveConversationTurn(
        userId: 'u_sync',
        userText: '이것은 매우 긴 사용자 발화 내용이라서 15자를 초과합니다',
        userTime: DateTime.now(),
        aiText: '답변 2',
        aiTime: DateTime.now(),
      );

      expect(repo.pendingSyncTurns.length, 2);

      // Now enable mockHttp to succeed
      failSave = false;

      final synced = await repo.syncPendingTurns();
      expect(synced, 2);
      expect(repo.pendingSyncTurns, isEmpty);
    });

    test('syncPendingTurns breaks safely on exception', () async {
      final mockHttp = MockClient((req) async {
        throw Exception('네트워크 중단');
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      await repo.saveConversationTurn(
        userId: 'u_sync_fail',
        userText: '실패 발화',
        userTime: DateTime.now(),
        aiText: '실패 응답',
        aiTime: DateTime.now(),
      );
      expect(repo.pendingSyncTurns.length, 1);

      final synced = await repo.syncPendingTurns();
      expect(synced, 0);
      expect(repo.pendingSyncTurns.length, 1);
    });

    test('fetchConversations handles TimeoutException and PostgrestException', () async {
      // 1. TimeoutException
      final mockHttpTimeout = MockClient((req) async {
        throw TimeoutException('Supabase query timeout');
      });
      final supabaseTimeout = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttpTimeout);
      final repoTimeout = ConversationRepository(supabaseClient: supabaseTimeout);
      final resTimeout = await repoTimeout.fetchConversations(userId: 'u_test');
      expect(resTimeout, isNotNull);

      // 2. PostgrestException
      final mockHttpPostgrest = MockClient((req) async {
        return http.Response(
          jsonEncode({'message': 'relation not found', 'code': '42P01'}),
          400,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      });
      final supabasePostgrest = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttpPostgrest);
      final repoPostgrest = ConversationRepository(supabaseClient: supabasePostgrest);
      final resPostgrest = await repoPostgrest.fetchConversations(userId: 'u_test');
      expect(resPostgrest, isNotNull);
    });
  });

  group('VoiceChatNotifier & AuthNotifier Edge Cases Tests', () {
    test('handleAudioInterruption sets errorMessage and ends active call', () async {
      final repo = ConversationRepository();
      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              openAiService: OpenAiService(apiKey: 'sk-test'),
              sttService: MockSttServiceForEdgeCases(),
              ttsService: MockTtsServiceForEdgeCases(),
              repository: repo,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceChatProvider.notifier);

      // Start call
      await notifier.toggleRecording();
      expect(container.read(voiceChatProvider).isCallActive, isTrue);

      // Call handleAudioInterruption with custom reason
      await notifier.handleAudioInterruption(reason: '전화 수신으로 통화 중단');
      expect(container.read(voiceChatProvider).errorMessage, '전화 수신으로 통화 중단');
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);

      // Call handleAudioInterruption without reason (default reason)
      await notifier.toggleRecording();
      await notifier.handleAudioInterruption();
      expect(container.read(voiceChatProvider).errorMessage, contains('전화 수신 또는 다른 앱의 오디오 사용'));
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.idle);
    });

    test('STT initialize exception is caught and logged', () async {
      final repo = ConversationRepository();
      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              openAiService: OpenAiService(apiKey: 'sk-test'),
              sttService: ThrowingInitSttService(),
              ttsService: MockTtsServiceForEdgeCases(),
              repository: repo,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceChatProvider.notifier);
      await notifier.toggleRecording();
      expect(container.read(voiceChatProvider).status, VoiceChatStatus.recording);
    });

    test('CancelledException during voice turn handles gracefully without crashing', () async {
      final repo = ConversationRepository();
      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              openAiService: ThrowingCancelledAiService(),
              sttService: MockSttServiceForEdgeCases(),
              ttsService: MockTtsServiceForEdgeCases(),
              repository: repo,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceChatProvider.notifier);

      // Start call (MockSttServiceForEdgeCases emits '인식된 음성 발화' immediately)
      await notifier.toggleRecording();
      expect(container.read(voiceChatProvider).recognizedText, '인식된 음성 발화');

      // Trigger stop recording to process speech with the throwing CancelledException AI service
      await notifier.toggleRecording();

      expect(container.read(voiceChatProvider).status, isNot(VoiceChatStatus.recording));
    });

    test('AuthNotifier loginWithKakaoId handles userId fallback', () async {
      final mockHttp = MockClient((req) async {
        final path = req.url.path;
        if (path.contains('/auth/v1/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'test_token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'refresh_token',
              'user': {
                'id': 'auth_uuid_777',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'kakao_test@present.internal',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        } else if (path.contains('/rest/v1/users')) {
          // upsert succeeds, returns record where id is empty
          return http.Response(
            jsonEncode({
              'id': '',
              'kakao_id': 'kakao_fallback_1',
              'name': '폴백유저',
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }
        return http.Response('Not Found', 404, request: req);
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabase)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      await notifier.loginWithKakaoId('kakao_fallback_1', '폴백유저');
      final state = container.read(authProvider);
      expect(state.hasValue, isTrue);
      expect(state.value?.id, 'auth_uuid_777');
    });

    test('AuthNotifier bypassLoginForTest throws when user is null', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'access_token': 'anon_token',
            'token_type': 'bearer',
            'user': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabase)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      await notifier.bypassLoginForTest();
      final state = container.read(authProvider);
      expect(state.hasError, isTrue);
    });

    test('AuthNotifier logout catches signOut and cache clear errors safely', () async {
      final mockHttp = MockClient((req) async {
        throw Exception('SignOut network failure');
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabase)),
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              openAiService: OpenAiService(apiKey: 'sk-test'),
              sttService: MockSttServiceForEdgeCases(),
              ttsService: MockTtsServiceForEdgeCases(),
              repository: ThrowingClearCacheRepo(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      await notifier.logout();
      final state = container.read(authProvider);
      expect(state.value, isNull);
    });
  });
}
