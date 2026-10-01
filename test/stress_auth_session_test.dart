import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:present_app/providers/auth_provider.dart';
import 'package:present_app/providers/conversation_list_provider.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Vulnerability #3: Auth Session & Multi-User Isolation Stress Tests', () {
    test('1. Rapid account switching (50 switches) leaves zero data bleed in repository cache', () async {
      final repo = ConversationRepository();
      final container = ProviderContainer(
        overrides: [
          conversationListProvider.overrideWith(() => ConversationListNotifier()),
        ],
      );
      addTearDown(container.dispose);

      for (int i = 0; i < 50; i++) {
        final userId = 'user_${i % 2 == 0 ? "alpha" : "beta"}';
        
        // 1. 유저 대화 저장
        await repo.saveConversationTurn(
          userId: userId,
          userText: '질문 $i',
          userTime: DateTime.now(),
          aiText: '답변 $i',
          aiTime: DateTime.now(),
        );

        // 2. 로그아웃 및 캐시 초기화
        container.read(conversationListProvider.notifier).clear();
        repo.clearLocalCache();
        expect(repo.localConversations.isEmpty, isTrue);
        expect(container.read(conversationListProvider).value?.isEmpty ?? true, isTrue);
      }
    });

    test('2. AuthNotifier fallback generates valid UserModel even when profile query fails', () async {
      final user = User(
        id: 'stress_test_user_id_12345',
        appMetadata: {},
        userMetadata: {
          'kakao_id': 'stress_kakao_9999',
          'name': '스트레스 테스터',
        },
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      final notifier = AuthNotifier(
        supabaseClient: null, // 클라이언트 부재 시뮬레이션
        initialUser: user,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authProvider.future);
      expect(authState, isNotNull);
      expect(authState!.id, 'stress_test_user_id_12345');
      expect(authState.kakaoId, 'stress_kakao_9999');
      expect(authState.name, '스트레스 테스터');
    });

    test('3. AuthNotifier with completely empty metadata still creates defensive UserModel', () async {
      final user = User(
        id: 'usr_bare_bones',
        appMetadata: {},
        userMetadata: null,
        aud: 'authenticated',
        createdAt: 'invalid-date-format',
      );

      final notifier = AuthNotifier(
        supabaseClient: null,
        initialUser: user,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authProvider.future);
      expect(authState, isNotNull);
      expect(authState!.id, 'usr_bare_bones');
      expect(authState.kakaoId?.contains('anonymous_'), isTrue);
      expect(authState.name, '익명 테스터');
      expect(authState.createdAt, isNotNull);
    });
  });
}
