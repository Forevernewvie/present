import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:present_app/config/env.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/models/chat_message_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Physical Device E2E: 4-Turn Ping-Pong with Gemini 3.6 Flash', (tester) async {
    debugPrint('\n[E2E TEST 시작] 실제 디바이스 환경에서 4회 핑퐁 대화 테스트');
    
    try {
      await dotenv.load(fileName: ".env.dev");
    } catch (_) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (_) {}
    }

    // 1. Supabase 초기화
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;
    final authRes = await supabase.auth.signInAnonymously();
    final userId = authRes.user!.id;

    try { 
      await supabase.from('users').upsert({'id': userId, 'kakao_id': 'device_e2e_$userId', 'name': 'Device Tester'}).select(); 
    } catch (_) {}

    final repo = ConversationRepository();
    final aiService = OpenAiService();

    final userMessages = [
      '안녕? 오늘 날씨 어때?',
      '그렇구나. 점심은 뭐 먹을까?',
      '좋은 생각이네! 그거 먹어야겠다.',
      '고마워, 내일 또 올게. 안녕!'
    ];

    debugPrint('====================================');
    for (int i = 0; i < userMessages.length; i++) {
      final turn = i + 1;
      debugPrint('\n[Turn $turn] 사용자가 말합니다: "${userMessages[i]}"');
      
      final userTime = DateTime.now();
      
      // 히스토리 불러오기
      await repo.fetchConversations(userId: userId);
      final history = repo.localConversations.isNotEmpty 
          ? repo.localConversations.first.messages 
          : <ChatMessageModel>[];
      
      // AI 응답 받기
      debugPrint('   -> Gemini API (3.6-flash) 호출 중...');
      final aiReply = await aiService.getAiReply(
        userMessage: userMessages[i], 
        history: history
      );
      final aiTime = DateTime.now();
      debugPrint('   -> AI 답변: "$aiReply"');
      
      expect(aiReply.isNotEmpty, isTrue, reason: 'AI 답변이 비어있으면 안 됩니다.');
      
      // DB 저장
      debugPrint('   -> Supabase DB에 턴 저장 중...');
      await repo.saveConversationTurn(
        userId: userId,
        userText: userMessages[i],
        userTime: userTime,
        aiText: aiReply,
        aiTime: aiTime,
      );
      
      debugPrint('   -> Turn $turn 성공!');
    }

    debugPrint('\n[최종 검증] DB에 4회의 대화(8개의 메시지)가 정상적으로 스택되었는지 확인합니다.');
    final fetched = await repo.fetchConversations(userId: userId);
    final todaysConv = fetched.where((c) => 
      c.date.year == DateTime.now().year && c.date.day == DateTime.now().day
    ).toList();
    
    expect(todaysConv.isNotEmpty, isTrue, reason: '오늘 날짜의 대화방이 있어야 합니다.');
    
    final finalMessageCount = todaysConv.first.messages.length;
    debugPrint('   -> 현재 스택된 메시지 수: $finalMessageCount 개');
    
    // 이전 테스트 내역이 있을 수 있으므로 최소 8개 이상이어야 함
    expect(finalMessageCount >= 8, isTrue, reason: '최소 8개(4턴 왕복)의 메시지가 저장되어야 합니다.');

    debugPrint('\n🎉 실제 디바이스 E2E 4회 핑퐁 테스트 0 에러 통과 🎉');
    debugPrint('====================================\n');
  });
}
