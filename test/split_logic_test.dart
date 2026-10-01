import 'package:flutter_test/flutter_test.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('1-day 1-room logic verifies successfully', () async {
    // Mock Supabase HTTP Client to prevent hanging and test logic instantly
    final mockHttp = MockClient((req) async {
      final path = req.url.path;
      final method = req.method;
      
      if (path.contains('conversations') && method == 'POST') {
        return http.Response(
          jsonEncode({
            'id': 'conv_mock_${DateTime.now().millisecondsSinceEpoch}',
            'user_id': 'test_user',
            'date': '2026-09-12',
            'summary': 'Mock Summary',
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
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final morning = today.add(const Duration(hours: 9));
    final evening = today.add(const Duration(hours: 19));
    
    // 1. 첫 번째 대화 (같은 날 아침 9시)
    await repo.saveConversationTurn(
      userId: 'test_user',
      userText: '첫 번째 대화입니다',
      userTime: morning,
      aiText: '네 안녕하세요',
      aiTime: morning.add(const Duration(seconds: 2)),
    );
    
    expect(repo.localConversations.length, 1, reason: '첫 대화방이 생성되어야 함');
    
    // 2. 두 번째 대화 (같은 날 저녁 7시 - 10시간 경과) -> 1일 1방 룰에 따라 기존 방에 통합되어야 함
    await repo.saveConversationTurn(
      userId: 'test_user',
      userText: '10시간 뒤 새로운 대화입니다',
      userTime: evening,
      aiText: '같은 방에 이어집니다',
      aiTime: evening.add(const Duration(seconds: 2)),
    );
    
    expect(repo.localConversations.length, 1, reason: '1일 1방 정책으로 인해 방이 분리되지 않아야 함');
    expect(repo.localConversations[0].messages.length, 4, reason: '첫 번째 방에 메시지가 계속 추가되어야 함');
  });
}
