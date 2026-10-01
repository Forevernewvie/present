import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:present_app/services/conversation_repository.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Vulnerability #4: Supabase DB Concurrency & Write Stress Tests', () {
    test('1. 30 concurrent saveConversationTurn calls on same date are bundled into 1 room', () async {
      final repo = ConversationRepository();
      final now = DateTime.now();

      // 30개의 턴을 동시에 저장 시도
      final futures = List.generate(30, (i) {
        return repo.saveConversationTurn(
          userId: 'stress_db_user',
          userText: '동시 질문 $i',
          userTime: now.add(Duration(milliseconds: i * 10)),
          aiText: '동시 답변 $i',
          aiTime: now.add(Duration(milliseconds: i * 10 + 5)),
        );
      });

      await Future.wait(futures);

      // 같은 날짜이므로 단 1개의 방만 생성되어야 함
      expect(repo.localConversations.length, 1);
      // 30턴 * 2메시지 = 60개 메시지가 안전하게 누적되어야 함
      expect(repo.localConversations.first.messages.length, 60);
    });

    test('2. Multi-day turns (7 distinct days) create exactly 7 distinct conversation rooms', () async {
      final repo = ConversationRepository();
      final baseDate = DateTime(2026, 9, 1);

      for (int day = 0; day < 7; day++) {
        final date = baseDate.add(Duration(days: day));
        await repo.saveConversationTurn(
          userId: 'stress_multi_day_user',
          userText: '$day일차 질문',
          userTime: date,
          aiText: '$day일차 답변',
          aiTime: date.add(const Duration(seconds: 1)),
        );
      }

      expect(repo.localConversations.length, 7);
      for (final conv in repo.localConversations) {
        expect(conv.messages.length, 2);
      }
    });

    test('3. Rapid save and fetch cycle (50 iterations) preserves data consistency', () async {
      final repo = ConversationRepository();

      for (int i = 0; i < 50; i++) {
        await repo.saveConversationTurn(
          userId: 'user_cycle',
          userText: '반복 질문 $i',
          userTime: DateTime.now(),
          aiText: '반복 답변 $i',
          aiTime: DateTime.now(),
        );

        expect(repo.localConversations.isNotEmpty, isTrue);
      }

      expect(repo.localConversations.first.messages.length, 100);
    });
  });
}
