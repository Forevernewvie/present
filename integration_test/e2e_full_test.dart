import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:present_app/config/env.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full E2E: Gemini API -> DB Stacking', (tester) async {
    try {
      await dotenv.load(fileName: ".env.dev");
    } catch (_) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (_) {}
    }

    // integration_test 에서는 실제 HTTP 요청이 통과됩니다.
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;
    final authRes = await supabase.auth.signInAnonymously();
    final userId = authRes.user!.id;

    try { await supabase.from('users').upsert({'id': userId, 'kakao_id': 'e2e_$userId', 'name': 'E2E Tester'}).select(); } catch (_) {}
    
    final repo = ConversationRepository();
    final aiService = OpenAiService();

    debugPrint('\n[E2E TEST 시작]');
    debugPrint('1. STT Mock: 사용자가 말을 걸었습니다.');
    final userText = '안녕하세요, 오늘 날씨가 참 좋네요.';
    final userTime = DateTime.now();

    debugPrint('2. AI Processing: Gemini API 호출 (최신 3.6 Flash 모델)');
    final aiReply = await aiService.getAiReply(userMessage: userText);
    final aiTime = DateTime.now();
    debugPrint('   -> AI 답변: $aiReply');
    expect(aiReply.isNotEmpty, isTrue);

    debugPrint('3. DB Saving: 1회차 대화(Turn 1) Supabase 저장 중...');
    await repo.saveConversationTurn(
      userId: userId,
      userText: userText,
      userTime: userTime,
      aiText: aiReply,
      aiTime: aiTime,
    );

    debugPrint('4. STT Mock 2: 사용자가 다시 대답합니다.');
    final userText2 = '네, 기분이 아주 좋습니다.';
    final userTime2 = DateTime.now().add(const Duration(seconds: 1));
    
    debugPrint('5. AI Processing 2: 맥락(History)을 포함하여 Gemini API 다시 호출');
    await repo.fetchConversations(userId: userId);
    final history = repo.localConversations.first.messages;
    
    final aiReply2 = await aiService.getAiReply(userMessage: userText2, history: history);
    final aiTime2 = DateTime.now().add(const Duration(seconds: 2));
    debugPrint('   -> AI 답변 2: $aiReply2');

    debugPrint('6. DB Saving: 2회차 대화(Turn 2) 누적(Stacking) 저장 중...');
    await repo.saveConversationTurn(
      userId: userId,
      userText: userText2,
      userTime: userTime2,
      aiText: aiReply2,
      aiTime: aiTime2,
    );

    debugPrint('7. Verification: 앱 재시작을 가정하여 DB에서 기록 다시 불러오기');
    final fetched = await repo.fetchConversations(userId: userId);
    final todaysConv = fetched.where((c) => 
      c.date.year == DateTime.now().year && c.date.day == DateTime.now().day
    ).toList();

    expect(todaysConv.length, 1, reason: '1일 1방 통합 실패');
    expect(todaysConv.first.messages.length, 4, reason: '말풍선 4개(양방향 2번) 누적 실패');

    debugPrint('\n====================================');
    debugPrint('🎉 E2E TEST 완벽 성공 🎉');
    debugPrint('- 오늘 날짜 대화방 수: ${todaysConv.length}개 (1일 1방 규칙 일치)');
    debugPrint('- 누적된 총 메시지 수: ${todaysConv.first.messages.length}개 (히스토리 스택 일치)');
    debugPrint('====================================\n');
  });
}
