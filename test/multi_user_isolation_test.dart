import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:present_app/providers/auth_provider.dart';
import 'package:present_app/providers/conversation_list_provider.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/services/tts_service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSpeechToText extends SpeechToText {
  MockSpeechToText() : super.withMethodChannel();

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
    dynamic debugLogging,
    List<dynamic>? options,
    Duration? finalTimeout,
  }) async => true;

  @override
  Future<void> stop() async {}
}

class MockTtsService extends TtsService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// Supabase Auth 및 Postgrest DB의 동작을 메모리 상에서 완벽히 시뮬레이션하는 Stateful Mock Backend
class MockSupabaseBackend {
  final Map<String, Map<String, dynamic>> authUsersByEmail = {};
  final Map<String, Map<String, dynamic>> usersTable = {};
  final List<Map<String, dynamic>> conversationsTable = [];
  final List<Map<String, dynamic>> messagesTable = [];

  http.Client createHttpClient() {
    return MockClient((req) async {
      final path = req.url.path;
      final method = req.method;

      // 1. Supabase Auth: signInWithPassword
      if (path.contains('/auth/v1/token') && req.url.queryParameters['grant_type'] == 'password') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final email = body['email']?.toString() ?? '';
        final user = authUsersByEmail[email];

        if (user != null) {
          return http.Response(
            jsonEncode({
              'access_token': 'mock_token_${user['id']}',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'mock_refresh_${user['id']}',
              'user': user,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        } else {
          return http.Response(
            jsonEncode({
              'error': 'invalid_grant',
              'error_description': 'Invalid login credentials',
            }),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        }
      }

      // 2. Supabase Auth: signUp (최초 가입 시 영구 UUID 발급)
      if (path.contains('/auth/v1/signup')) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final email = body['email']?.toString() ?? '';
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final kakaoId = data['kakao_id']?.toString() ?? '';
        final name = data['name']?.toString() ?? '사용자';

        // 카카오 ID 기반 고유하고 결정론적인 영구 UUID 발급 시뮬레이션
        final permanentUuid = 'uuid_user_${kakaoId.isNotEmpty ? kakaoId : 'gen_${authUsersByEmail.length + 1}'}';
        final user = {
          'id': permanentUuid,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': email,
          'email_confirmed_at': DateTime.now().toIso8601String(),
          'user_metadata': {
            'kakao_id': kakaoId,
            'name': name,
          },
          'app_metadata': {
            'provider': 'email',
            'providers': ['email'],
          },
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        authUsersByEmail[email] = user;

        return http.Response(
          jsonEncode({
            'access_token': 'mock_token_$permanentUuid',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'mock_refresh_$permanentUuid',
            'user': user,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: req,
        );
      }

      // 3. Supabase Auth: signOut
      if (path.contains('/auth/v1/logout')) {
        return http.Response('{}', 200, headers: {'content-type': 'application/json'}, request: req);
      }

      // 4. DB: users table (Upsert & Select)
      if (path.contains('/rest/v1/users')) {
        if (method == 'POST') {
          final dynamic body = jsonDecode(req.body);
          final record = body is List
              ? Map<String, dynamic>.from(body.first as Map)
              : Map<String, dynamic>.from(body as Map);
          final kakaoId = record['kakao_id']?.toString() ?? '';
          final existing = usersTable[kakaoId];
          final userId = record['id']?.toString() ?? existing?['id'] ?? 'usr_$kakaoId';
          final row = {
            'id': userId,
            'kakao_id': kakaoId,
            'name': record['name'] ?? existing?['name'] ?? '사용자',
            'created_at': existing?['created_at'] ?? DateTime.now().toIso8601String(),
          };
          usersTable[kakaoId] = row;
          return http.Response(
            jsonEncode(row),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        } else if (method == 'GET') {
          final idFilter = req.url.queryParameters['id'];
          String? targetId;
          if (idFilter != null && idFilter.startsWith('eq.')) {
            targetId = idFilter.substring(3);
          }
          final user = usersTable.values.firstWhere(
            (u) => u['id'] == targetId,
            orElse: () => <String, dynamic>{},
          );
          if (user.isNotEmpty) {
            return http.Response(
              jsonEncode(user),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: req,
            );
          } else {
            return http.Response('null', 200, headers: {'content-type': 'application/json'}, request: req);
          }
        }
      }

      // 5. DB: conversations table (Insert & Select with User Isolation)
      if (path.contains('/rest/v1/conversations')) {
        if (method == 'POST') {
          final dynamic body = jsonDecode(req.body);
          final record = body is List
              ? Map<String, dynamic>.from(body.first as Map)
              : Map<String, dynamic>.from(body as Map);
          final convId = 'conv_db_${conversationsTable.length + 1}';
          final row = {
            'id': convId,
            'user_id': record['user_id']?.toString(),
            'date': record['date']?.toString(),
            'summary': record['summary']?.toString(),
            'created_at': record['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          };
          conversationsTable.add(row);
          return http.Response(
            jsonEncode(row),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        } else if (method == 'GET') {
          // 멀티 유저 격리 핵심: user_id=eq.XXX 쿼리 파라미터로만 필터링하여 반환
          final userFilter = req.url.queryParameters['user_id'];
          String? targetUserId;
          if (userFilter != null && userFilter.startsWith('eq.')) {
            targetUserId = userFilter.substring(3);
          }

          final filtered = conversationsTable.where((c) => c['user_id'] == targetUserId).toList();
          final result = filtered.map((c) {
            final msgs = messagesTable.where((m) => m['conversation_id'] == c['id']).toList();
            return {
              ...c,
              'messages': msgs,
            };
          }).toList();

          return http.Response(
            jsonEncode(result),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: req,
          );
        }
      }

      // 6. DB: messages table (Insert)
      if (path.contains('/rest/v1/messages')) {
        if (method == 'POST') {
          final dynamic body = jsonDecode(req.body);
          if (body is List) {
            for (var i = 0; i < body.length; i++) {
              final m = Map<String, dynamic>.from(body[i] as Map);
              m['id'] = 'msg_db_${messagesTable.length + 1}';
              messagesTable.add(m);
            }
          }
          return http.Response(
            jsonEncode([]),
            201,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }
      }

      return http.Response('Not Found: ${req.url}', 404, request: req);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('카카오 로그인 ↔ Supabase Auth 연동 및 멀티 유저 데이터 격리 실증 검증', () {
    late MockSupabaseBackend backend;
    late SupabaseClient supabaseClient;

    setUp(() {
      backend = MockSupabaseBackend();
      supabaseClient = SupabaseClient(
        'https://mock.supabase.co',
        'mock_anon_key',
        httpClient: backend.createHttpClient(),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
    });

    test('시나리오 (1)~(9): 유저 A/B 로그인, 대화 격리, 로그아웃 캐시 비우기, 앱 재설치 복원 전체 사이클 실증', () async {
      final repo = ConversationRepository(supabaseClient: supabaseClient);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabaseClient)),
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

      // (1) 유저 A 로그인: loginWithKakaoId('kakao_11111', '유저A') 호출 시 영구 UUID user_id_A 발급 확인
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.loginWithKakaoId('kakao_11111', '유저A');

      final userA = container.read(authProvider).asData?.value;
      expect(userA, isNotNull);
      expect(userA!.kakaoId, 'kakao_11111');
      expect(userA.name, '유저A');
      expect(userA.id, isNotEmpty);
      expect(userA.id.startsWith('uuid_user_kakao_11111'), isTrue);
      final userIdA = userA.id;

      // (2) 유저 A 대화 저장: user_id_A로 대화 턴 저장 (saveConversationTurn)
      final userTimeA = DateTime(2026, 9, 22, 10, 0);
      final aiTimeA = DateTime(2026, 9, 22, 10, 0, 5);
      await repo.saveConversationTurn(
        userId: userIdA,
        userText: '안녕하세요 Present! 유저A의 비밀 일기입니다.',
        userTime: userTimeA,
        aiText: '안녕하세요 유저A님! 오늘 어떤 하루를 보내셨나요?',
        aiTime: aiTimeA,
      );

      expect(repo.localConversations.length, 1);
      expect(repo.localConversations.first.userId, userIdA);
      expect(repo.localConversations.first.messages.length, 2);
      expect(repo.localConversations.first.messages.first.content, '안녕하세요 Present! 유저A의 비밀 일기입니다.');

      // (3) 유저 A 대화 조회: fetchConversations(userId: user_id_A)로 조회 시 유저 A의 대화만 조회됨 확인
      final convsA = await repo.fetchConversations(userId: userIdA);
      expect(convsA.length, 1);
      expect(convsA.first.userId, userIdA);
      expect(convsA.first.messages.length, 2);
      expect(convsA.first.messages.first.content, contains('유저A의 비밀 일기'));
      expect(convsA.first.messages.last.content, contains('안녕하세요 유저A님'));

      // (4) 유저 A 로그아웃: logout() 호출 시 세션 null 확인 및 localConversations 캐시가 깨끗이 비워졌는지 확인
      await authNotifier.logout();
      expect(container.read(authProvider).asData?.value, isNull);
      expect(repo.localConversations, isEmpty);

      // (5) 유저 B 로그인: loginWithKakaoId('kakao_22222', '유저B') 호출 시 유저 A와 다른 고유 UUID user_id_B 발급 확인 (user_id_A != user_id_B)
      await authNotifier.loginWithKakaoId('kakao_22222', '유저B');

      final userB = container.read(authProvider).asData?.value;
      expect(userB, isNotNull);
      expect(userB!.kakaoId, 'kakao_22222');
      expect(userB.name, '유저B');
      expect(userB.id, isNotEmpty);
      expect(userB.id.startsWith('uuid_user_kakao_22222'), isTrue);
      final userIdB = userB.id;

      expect(userIdA != userIdB, isTrue, reason: '유저 A와 유저 B의 영구 UUID는 고유하게 분리되어야 합니다.');

      // (6) 유저 B 데이터 격리 확인: 유저 B가 대화를 조회할 때 유저 A의 대화가 절대 노출되지 않음 확인
      final convsBBeforeSave = await repo.fetchConversations(userId: userIdB);
      expect(convsBBeforeSave, isEmpty, reason: '유저 B의 대화 목록에 유저 A의 대화가 노출되어서는 안 됩니다.');
      expect(repo.localConversations, isEmpty);

      // (7) 유저 B 대화 저장: user_id_B로 새로운 대화 저장
      final userTimeB = DateTime(2026, 9, 22, 11, 0);
      final aiTimeB = DateTime(2026, 9, 22, 11, 0, 5);
      await repo.saveConversationTurn(
        userId: userIdB,
        userText: '저는 유저B입니다. 완전히 새로운 계정입니다.',
        userTime: userTimeB,
        aiText: '반갑습니다 유저B님! 오늘 어떤 대화를 나눌까요?',
        aiTime: aiTimeB,
      );

      expect(repo.localConversations.length, 1);
      expect(repo.localConversations.first.userId, userIdB);
      expect(repo.localConversations.first.messages.first.content, contains('유저B입니다'));

      final convsBAfterSave = await repo.fetchConversations(userId: userIdB);
      expect(convsBAfterSave.length, 1);
      expect(convsBAfterSave.first.userId, userIdB);
      expect(convsBAfterSave.first.messages.first.content, contains('유저B입니다'));

      // (8) 유저 B 로그아웃: 캐시 및 세션 완전 초기화 확인
      await authNotifier.logout();
      expect(container.read(authProvider).asData?.value, isNull);
      expect(repo.localConversations, isEmpty);

      // (9) 앱 재설치/재로그인 시뮬레이션:
      // 앱이 삭제되고 다시 설치된 상태를 시뮬레이션하기 위해 완전히 새로운 SupabaseClient, Repository, ProviderContainer 생성
      final reinstalledSupabaseClient = SupabaseClient(
        'https://mock.supabase.co',
        'mock_anon_key',
        httpClient: backend.createHttpClient(),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
      final reinstalledRepo = ConversationRepository(supabaseClient: reinstalledSupabaseClient);
      expect(reinstalledRepo.localConversations, isEmpty);

      final reinstalledContainer = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(supabaseClient: reinstalledSupabaseClient)),
          voiceChatProvider.overrideWith(
            () => VoiceChatNotifier(
              repository: reinstalledRepo,
              ttsService: MockTtsService(),
              speech: MockSpeechToText(),
            ),
          ),
        ],
      );
      addTearDown(reinstalledContainer.dispose);

      final reinstalledAuthNotifier = reinstalledContainer.read(authProvider.notifier);

      // 유저 A가 다시 loginWithKakaoId('kakao_11111', '유저A')로 로그인했을 때:
      await reinstalledAuthNotifier.loginWithKakaoId('kakao_11111', '유저A');
      final restoredUserA = reinstalledContainer.read(authProvider).asData?.value;

      // 1) 이전과 동일한 영구 UUID user_id_A를 그대로 복원받는지 확인
      expect(restoredUserA, isNotNull);
      expect(restoredUserA!.id, userIdA, reason: '재로그인 시 동일한 영구 UUID가 복원되어야 합니다.');
      expect(restoredUserA.kakaoId, 'kakao_11111');
      expect(restoredUserA.name, '유저A');

      // 2) fetchConversations 호출 시 유저 A의 이전 대화 기록이 100% 복원되는지 확인
      final restoredConvsA = await reinstalledRepo.fetchConversations(userId: restoredUserA.id);
      expect(restoredConvsA.length, 1, reason: '유저 A의 과거 대화가 정확히 1건 복원되어야 합니다.');
      expect(restoredConvsA.first.userId, userIdA);
      expect(restoredConvsA.first.messages.length, 2);
      expect(restoredConvsA.first.messages.first.content, contains('유저A의 비밀 일기입니다'));
      expect(restoredConvsA.first.messages.last.content, contains('안녕하세요 유저A님'));

      // 3) 유저 B의 대화 기록은 유저 A에게 일절 섞이지 않는지 확인
      final hasUserBData = restoredConvsA.any((c) => c.userId == userIdB || c.messages.any((m) => m.content.contains('유저B')));
      expect(hasUserBData, isFalse, reason: '유저 B의 대화 기록이 유저 A의 복원 목록에 절대 포함되어서는 안 됩니다.');
    });

    test('ConversationListNotifier와 Riverpod 상태 연동 멀티 유저 격리 검증', () async {
      final repo = ConversationRepository(supabaseClient: supabaseClient);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(supabaseClient: supabaseClient)),
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

      final authNotifier = container.read(authProvider.notifier);

      // 1. 유저 1 로그인 및 대화 저장
      await authNotifier.loginWithKakaoId('kakao_user_1', '유저1');
      final user1 = container.read(authProvider).asData?.value;
      expect(user1, isNotNull);

      await repo.saveConversationTurn(
        userId: user1!.id,
        userText: '유저1 메시지',
        userTime: DateTime.now(),
        aiText: '유저1 응답',
        aiTime: DateTime.now(),
      );

      await container.read(conversationListProvider.notifier).refresh();
      final listUser1 = container.read(conversationListProvider).asData?.value;
      expect(listUser1?.length, 1);
      expect(listUser1?.first.userId, user1.id);

      // 2. 로그아웃 시 대화 목록 provider 및 캐시 초기화 확인
      await authNotifier.logout();
      container.read(conversationListProvider.notifier).clear();
      final listAfterLogout = container.read(conversationListProvider).asData?.value;
      expect(listAfterLogout, isEmpty);
      expect(repo.localConversations, isEmpty);

      // 3. 유저 2 로그인 시 이전 유저 1의 대화가 전혀 보이지 않음 확인
      await authNotifier.loginWithKakaoId('kakao_user_2', '유저2');
      final user2 = container.read(authProvider).asData?.value;
      expect(user2, isNotNull);
      expect(user2!.id != user1.id, isTrue);

      await container.read(conversationListProvider.notifier).refresh();
      final listUser2 = container.read(conversationListProvider).asData?.value;
      expect(listUser2, isEmpty);
    });

    test('DB 수준 격리: 타인의 userId로 조회 시도 시 해당 유저 데이터만 반환됨 검증', () async {
      final repo = ConversationRepository(supabaseClient: supabaseClient);

      // 유저 100과 유저 200 데이터 미리 백엔드에 시딩
      backend.conversationsTable.add({
        'id': 'conv_100',
        'user_id': 'uuid_100',
        'date': '2026-09-22',
        'summary': '유저 100의 대화',
        'created_at': DateTime.now().toIso8601String(),
      });
      backend.messagesTable.add({
        'id': 'msg_100_1',
        'conversation_id': 'conv_100',
        'sender': 'user',
        'content': '100번 비밀',
        'created_at': DateTime.now().toIso8601String(),
      });

      backend.conversationsTable.add({
        'id': 'conv_200',
        'user_id': 'uuid_200',
        'date': '2026-09-22',
        'summary': '유저 200의 대화',
        'created_at': DateTime.now().toIso8601String(),
      });
      backend.messagesTable.add({
        'id': 'msg_200_1',
        'conversation_id': 'conv_200',
        'sender': 'user',
        'content': '200번 비밀',
        'created_at': DateTime.now().toIso8601String(),
      });

      // uuid_100으로 조회 시 uuid_100만 조회됨
      final result100 = await repo.fetchConversations(userId: 'uuid_100');
      expect(result100.length, 1);
      expect(result100.first.id, 'conv_100');
      expect(result100.first.userId, 'uuid_100');
      expect(result100.first.messages.first.content, '100번 비밀');

      // uuid_200으로 조회 시 uuid_200만 조회됨
      final result200 = await repo.fetchConversations(userId: 'uuid_200');
      expect(result200.length, 1);
      expect(result200.first.id, 'conv_200');
      expect(result200.first.userId, 'uuid_200');
      expect(result200.first.messages.first.content, '200번 비밀');

      // 존재하지 않는 uuid_300 조회 시 빈 리스트
      final result300 = await repo.fetchConversations(userId: 'uuid_300');
      expect(result300, isEmpty);
    });
  });
}
