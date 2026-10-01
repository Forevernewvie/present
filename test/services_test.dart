import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:present_app/models/chat_message_model.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/tts_service.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fake FlutterTts for testing TtsService
class FakeFlutterTts extends FlutterTts {
  bool setLanguageCalled = false;
  bool setSpeechRateCalled = false;
  bool speakCalled = false;
  bool stopCalled = false;
  int speakResult = 1;
  bool throwOnSpeak = false;
  bool throwOnStop = false;
  bool throwOnInit = false;
  bool autoCompleteSpeak = true;
  bool triggerErrorOnSpeak = false;
  void Function()? onSpeakStarted;

  void Function()? customStartHandler;
  void Function()? customCompletionHandler;
  void Function(dynamic)? customErrorHandler;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    return 1;
  }

  @override
  Future<dynamic> setSharedInstance(bool shared) async => 1;

  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async => 1;

  @override
  Future<dynamic> setLanguage(String language) async {

    if (throwOnInit) throw Exception('Init error');
    setLanguageCalled = true;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    setSpeechRateCalled = true;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    return 1;
  }

  @override
  void setStartHandler(void Function() callback) {
    customStartHandler = callback;
  }

  @override
  void setCompletionHandler(void Function() callback) {
    customCompletionHandler = callback;
  }

  @override
  void setErrorHandler(void Function(dynamic message) callback) {
    customErrorHandler = callback;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCalled = true;
    if (throwOnSpeak) throw Exception('Speak error');
    if (autoCompleteSpeak) {
      Future.microtask(() {
        customCompletionHandler?.call();
      });
    } else if (triggerErrorOnSpeak) {
      Future.microtask(() {
        customErrorHandler?.call('error during speak');
      });
    } else if (onSpeakStarted != null) {
      Future.microtask(() {
        onSpeakStarted?.call();
      });
    }
    return speakResult;
  }

  @override
  Future<dynamic> stop() async {
    stopCalled = true;
    if (throwOnStop) throw Exception('Stop error');
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OpenAiService Tests', () {
    test('hasKey behaves correctly', () {
      final noKeyService = OpenAiService(apiKey: '');
      expect(noKeyService.hasKey, isFalse);

      final keyService = OpenAiService(apiKey: 'sk-test12345');
      expect(keyService.hasKey, isTrue);
    });

    test('getAiReply throws Exception when hasKey is false', () async {
      final service = OpenAiService(apiKey: '   ');
      expect(
        () => service.getAiReply(userMessage: '안녕'),
        throwsA(isA<Exception>()),
      );
    });

    test('getAiReply succeeds with 200 OK and parses reply', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('chat/completions'));
        expect(request.headers['Authorization'], 'Bearer sk-mock-key');

        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(reqBody['model'], anyOf('gemini-flash-lite-latest', 'gpt-4o-mini'));
        expect(reqBody['messages'], isNotEmpty);

        final responseJson = {
          'choices': [
            {
              'message': {'content': '  안녕하세요! 오늘 날씨가 참 좋습니다.  '}
            }
          ]
        };

        return http.Response(
          jsonEncode(responseJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-mock-key');
      final reply = await service.getAiReply(userMessage: '오늘 날씨 어때?');
      expect(reply, '안녕하세요! 오늘 날씨가 참 좋습니다.');
    });

    test('getAiReply handles history length > 4 correctly', () async {
      final history = List.generate(
        6,
        (i) => ChatMessageModel(
          id: '$i',
          sender: i.isEven ? 'user' : 'ai',
          content: '대화 $i',
          createdAt: DateTime.now(),
        ),
      );

      final mockClient = MockClient((request) async {
        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = reqBody['messages'] as List<dynamic>;
        // system + 4 history items + 1 userMessage = 6 items
        expect(messages.length, 6);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '답변입니다.'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-mock-key');
      final reply = await service.getAiReply(userMessage: '마지막 질문', history: history);
      expect(reply, '답변입니다.');
    });

    test('getAiReply throws on empty choices', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'choices': []}), 200);
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-mock-key');
      expect(
        () => service.getAiReply(userMessage: '질문'),
        throwsA(isA<Exception>()),
      );
    });

    test('getAiReply throws on API error status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid API Key'}
          }),
          401,
        );
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-bad-key');
      expect(
        () => service.getAiReply(userMessage: '질문'),
        throwsA(predicate((e) => e.toString().contains('Invalid API Key'))),
      );
    });

    test('getAiReply rethrows network exception', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-mock-key');
      expect(
        () => service.getAiReply(userMessage: '질문'),
        throwsA(predicate((e) => e is Exception && e.toString().contains('네트워크 오류'))),
      );
    });

    test('getAiReply throws TimeoutException properly', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Timeout');
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-mock-key');
      expect(
        () => service.getAiReply(userMessage: '질문'),
        throwsA(predicate((e) => e is Exception && e.toString().contains('네트워크 지연'))),
      );
    });
  });

  group('TtsService Tests', () {
    test('TtsService speak and stop flow with FakeFlutterTts', () async {
      final fakeTts = FakeFlutterTts();
      final ttsService = TtsService(tts: fakeTts);

      await ttsService.speak('테스트 발화');
      expect(fakeTts.setLanguageCalled, isTrue);
      expect(fakeTts.setSpeechRateCalled, isTrue);
      expect(fakeTts.speakCalled, isTrue);

      // Trigger start handler & error handler to cover callbacks
      fakeTts.customStartHandler?.call();
      fakeTts.customErrorHandler?.call('Some warning');

      await ttsService.stop();
      expect(fakeTts.stopCalled, isTrue);

      ttsService.dispose();
    });

    test('TtsService handles speak result != 1 and exceptions safely', () async {
      final fakeTts = FakeFlutterTts();
      fakeTts.speakResult = 0;
      final ttsService = TtsService(tts: fakeTts);

      await ttsService.speak('결과가 0인 발화');
      expect(fakeTts.speakCalled, isTrue);

      // Exception on speak
      fakeTts.throwOnSpeak = true;
      await ttsService.speak('에러 발화');

      // Exception on stop
      fakeTts.throwOnStop = true;
      await ttsService.stop();
    });

    test('TtsService handles init error gracefully', () async {
      final fakeTts = FakeFlutterTts()..throwOnInit = true;
      final ttsService = TtsService(tts: fakeTts);
      await ttsService.speak('초기화 실패 발화');
      expect(fakeTts.speakCalled, isFalse);
    });

    test('TtsService stop completes active speak completer', () async {
      final fakeTts = FakeFlutterTts()..autoCompleteSpeak = false;
      final ttsService = TtsService(tts: fakeTts);
      fakeTts.onSpeakStarted = () => ttsService.stop();

      await ttsService.speak('긴 발화');
      expect(fakeTts.stopCalled, isTrue);
    });

    test('TtsService error handler completes active speak completer', () async {
      final fakeTts = FakeFlutterTts()
        ..autoCompleteSpeak = false
        ..triggerErrorOnSpeak = true;
      final ttsService = TtsService(tts: fakeTts);

      await ttsService.speak('에러날 발화');
      expect(fakeTts.speakCalled, isTrue);
    });
  });

  group('ConversationRepository Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveConversationTurn caches turn and updates existing turn on same day', () async {
      final repo = ConversationRepository();
      final userTime = DateTime(2026, 9, 11, 10, 0);
      final aiTime = DateTime(2026, 9, 11, 10, 1);

      // First turn
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '첫 번째 말',
        userTime: userTime,
        aiText: '첫 번째 대답',
        aiTime: aiTime,
      );

      expect(repo.localConversations.length, 1);
      expect(repo.localConversations.first.summary, '첫 번째 말');
      expect(repo.localConversations.first.messages.length, 2);

      // Second turn on same day
      final userTime2 = DateTime(2026, 9, 11, 10, 5);
      final aiTime2 = DateTime(2026, 9, 11, 10, 6);
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '두 번째 말',
        userTime: userTime2,
        aiText: '두 번째 대답',
        aiTime: aiTime2,
      );

      expect(repo.localConversations.length, 1);
      expect(repo.localConversations.first.summary, '첫 번째 말');
      expect(repo.localConversations.first.messages.length, 4);
    });

    test('saveConversationTurn and fetchConversations with null/empty userId', () async {
      final repo = ConversationRepository();
      await repo.saveConversationTurn(
        userId: null,
        userText: '유저 아이디 없음',
        userTime: DateTime.now(),
        aiText: '로컬 전용 대답',
        aiTime: DateTime.now(),
      );

      final list1 = await repo.fetchConversations(userId: null);
      expect(list1, repo.localConversations);

      final list2 = await repo.fetchConversations(userId: '');
      expect(list2, repo.localConversations);
    });

    test('saveConversationTurn with Supabase existing session', () async {
      final mockHttp = MockClient((req) async {
        final path = req.url.path;
        final method = req.method;

        if (path.contains('conversations') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 'conv_exist_100',
              'user_id': 'u1',
              'date': '2026-09-11',
              'summary': '이전 요약',
              'created_at': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        } else if (path.contains('conversations') && method == 'PATCH') {
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'}, request: req);
        } else if (path.contains('messages') && method == 'POST') {
          return http.Response(jsonEncode([]), 201, headers: {'content-type': 'application/json'}, request: req);
        }
        return http.Response('Not Found', 404, request: req);
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '기존 세션 질문',
        userTime: DateTime.now(),
        aiText: '기존 세션 답변',
        aiTime: DateTime.now(),
      );

      expect(repo.localConversations.isNotEmpty, isTrue);
      expect(repo.localConversations.first.summary, '기존 세션 질문');
    });

    test('saveConversationTurn with Supabase new session', () async {
      final mockHttp = MockClient((req) async {
        final path = req.url.path;
        final method = req.method;

        if (path.contains('conversations') && method == 'GET') {
          // maybeSingle returning 0 rows -> 200 with null or 406
          return http.Response('null', 200, headers: {'content-type': 'application/json'}, request: req);
        } else if (path.contains('conversations') && method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'conv_new_200',
              'user_id': 'u2',
              'date': '2026-09-11',
              'summary': '새 요약',
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        } else if (path.contains('messages') && method == 'POST') {
          return http.Response(jsonEncode([]), 201, headers: {'content-type': 'application/json'}, request: req);
        }
        return http.Response('Not Found', 404, request: req);
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      await repo.saveConversationTurn(
        userId: 'u2',
        userText: '새 세션 질문',
        userTime: DateTime.now(),
        aiText: '새 세션 답변',
        aiTime: DateTime.now(),
      );

      expect(repo.localConversations.isNotEmpty, isTrue);
      expect(repo.localConversations.first.summary, '새 세션 질문');
    });

    test('saveConversationTurn handles Supabase exception gracefully', () async {
      final mockHttp = MockClient((req) async {
        return http.Response('Internal Server Error', 500, request: req);
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      await repo.saveConversationTurn(
        userId: 'u3',
        userText: '에러 테스트 발화',
        userTime: DateTime.now(),
        aiText: '에러 테스트 응답',
        aiTime: DateTime.now(),
      );

      expect(repo.localConversations.isNotEmpty, isTrue);
    });

    test('fetchConversations parses Supabase data and handles error', () async {
      final now = DateTime(2026, 9, 11, 14, 0);
      final mockHttp = MockClient((req) async {
        // print('URL: ${req.url}, Method: ${req.method}');
        if (req.url.path.contains('conversations')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'conv_db_1',
                'user_id': 'u1',
                'date': now.toIso8601String(),
                'summary': '서버 대화 요약',
                'created_at': now.toIso8601String(),
                'messages': [
                  {
                    'id': 'm1',
                    'sender': 'user',
                    'content': '서버 유저 발화',
                    'created_at': now.toIso8601String(),
                  },
                  {
                    'id': 'm2',
                    'sender': 'ai',
                    'content': '서버 AI 응답',
                    'created_at': now.add(const Duration(seconds: 5)).toIso8601String(),
                  }
                ]
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        }
        return http.Response('Not Found', 404, request: req);
      });

      final supabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: mockHttp);
      final repo = ConversationRepository(supabaseClient: supabase);

      final result = await repo.fetchConversations(userId: 'u1');
      expect(result.length, 1);
      expect(result.first.id, 'conv_db_1');
      expect(result.first.summary, '서버 대화 요약');
      expect(result.first.messages.length, 2);

      // Empty list from Supabase
      final emptyMockHttp = MockClient((req) async {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'}, request: req);
      });
      final emptySupabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: emptyMockHttp);
      final emptyRepo = ConversationRepository(supabaseClient: emptySupabase);
      final emptyResult = await emptyRepo.fetchConversations(userId: 'u1');
      expect(emptyResult, isEmpty);

      // Offline/Error case (Resilience verification)
      // Populate local cache first
      final errorMockHttp = MockClient((req) async {
        throw Exception('DB Connection Failed');
      });
      final errorSupabase = SupabaseClient('https://mock.supabase.co', 'mock_key', httpClient: errorMockHttp);
      final errorRepo = ConversationRepository(supabaseClient: errorSupabase);
      
      // Simulate existing local cache
      await errorRepo.saveConversationTurn(
        userId: 'u1', 
        userText: '오프라인 유저', 
        userTime: DateTime.now(), 
        aiText: '오프라인 AI', 
        aiTime: DateTime.now()
      );
      
      // Fetching should fail over network but return the local cache
      final errorResult = await errorRepo.fetchConversations(userId: 'u1');
      expect(errorResult, isNotEmpty);
      expect(errorResult.first.summary, '오프라인 유저');
    });
  });

  group('OpenAiService Extra Coverage Tests', () {
    test('parses message as String or text and parses error as String', () async {
      // 1. message as String
      final mockClient1 = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': '문자열 메시지'}
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service1 = OpenAiService(client: mockClient1, apiKey: 'sk-test');
      final reply1 = await service1.getAiReply(userMessage: '안녕');
      expect(reply1, '문자열 메시지');

      // 2. text provided
      final mockClient2 = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {'text': '텍스트 메시지'}
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service2 = OpenAiService(client: mockClient2, apiKey: 'sk-test');
      final reply2 = await service2.getAiReply(userMessage: '안녕');
      expect(reply2, '텍스트 메시지');

      // 3. error as String
      final mockClient3 = MockClient((req) async {
        return http.Response(
          jsonEncode({'error': '문자열 에러 내용'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service3 = OpenAiService(client: mockClient3, apiKey: 'sk-test');
      expect(
        () => service3.getAiReply(userMessage: '안녕'),
        throwsA(predicate((e) => e.toString().contains('문자열 에러 내용'))),
      );

      // 4. PersonaType all values coverage
      for (final p in PersonaType.values) {
        expect(p.displayName, isNotEmpty);
        expect(p.systemPrompt, isNotEmpty);
      }

      // 5. OpenAiService default constructor (line 25 coverage)
      final defaultService = OpenAiService();
      expect(defaultService.hasKey, isA<bool>());
    });

    test('ConversationRepository trims cache when exceeding 50 conversations', () async {
      final repo = ConversationRepository();
      // Add 52 conversations on different days to force localConversations > 50
      for (int i = 0; i < 52; i++) {
        final day = DateTime(2026, 1, 1).add(Duration(days: i));
        await repo.saveConversationTurn(
          userId: 'u1',
          userText: '대화 $i',
          userTime: day,
          aiText: '답변 $i',
          aiTime: day,
        );
      }
      expect(repo.localConversations.length, 50);
    });

    test('clearLocalCache clears all conversations in memory', () async {
      final repo = ConversationRepository();
      await repo.saveConversationTurn(
        userId: 'u1',
        userText: '대화 내용',
        userTime: DateTime.now(),
        aiText: '응답 내용',
        aiTime: DateTime.now(),
      );
      expect(repo.localConversations.isNotEmpty, isTrue);
      repo.clearLocalCache();
      expect(repo.localConversations, isEmpty);
    });
  });
}
