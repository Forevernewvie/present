import 'package:flutter_test/flutter_test.dart';
import 'package:present_app/config/env.dart';
import 'package:present_app/models/chat_message_model.dart';
import 'package:present_app/models/conversation_model.dart';
import 'package:present_app/models/user_model.dart';

void main() {
  group('ChatMessageModel Tests', () {
    test('isUser and JSON serialization', () {
      final now = DateTime.now();
      final userMsg = ChatMessageModel(
        id: 'msg_1',
        conversationId: 'conv_1',
        sender: 'user',
        content: '안녕하세요',
        createdAt: now,
      );

      expect(userMsg.isUser, isTrue);
      final json = userMsg.toJson();
      expect(json['id'], 'msg_1');
      expect(json['conversation_id'], 'conv_1');
      expect(json['sender'], 'user');
      expect(json['content'], '안녕하세요');
      expect(json['created_at'], now.toIso8601String());

      final parsed = ChatMessageModel.fromJson(json);
      expect(parsed.id, 'msg_1');
      expect(parsed.conversationId, 'conv_1');
      expect(parsed.sender, 'user');
      expect(parsed.content, '안녕하세요');
      expect(parsed.createdAt, now);
      expect(parsed.isUser, isTrue);
    });

    test('ChatMessageModel.fromJson with empty or null fields', () {
      final parsed = ChatMessageModel.fromJson({});
      expect(parsed.id, '');
      expect(parsed.conversationId, isNull);
      expect(parsed.sender, 'user');
      expect(parsed.content, '');
      expect(parsed.createdAt, isNotNull);

      final aiMsg = ChatMessageModel(
        id: '',
        sender: 'ai',
        content: '반갑습니다',
        createdAt: DateTime.now(),
      );
      expect(aiMsg.isUser, isFalse);
      final json = aiMsg.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('conversation_id'), isFalse);
    });
  });

  group('ConversationModel Tests', () {
    test('toJson and fromJson with messages', () {
      final date = DateTime(2026, 9, 11);
      final createdAt = DateTime(2026, 9, 11, 14, 30);
      final msg = ChatMessageModel(
        id: 'm1',
        sender: 'user',
        content: '산책 가요',
        createdAt: createdAt,
      );

      final conv = ConversationModel(
        id: 'c1',
        userId: 'u1',
        date: date,
        summary: '산책 요약',
        createdAt: createdAt,
        messages: [msg],
      );

      final json = conv.toJson();
      expect(json['id'], 'c1');
      expect(json['user_id'], 'u1');
      expect(json['date'], '2026-09-11');
      expect(json['summary'], '산책 요약');
      expect(json['created_at'], createdAt.toIso8601String());

      final parsed = ConversationModel.fromJson(json, messages: [msg]);
      expect(parsed.id, 'c1');
      expect(parsed.userId, 'u1');
      expect(parsed.date.year, 2026);
      expect(parsed.summary, '산책 요약');
      expect(parsed.messages.length, 1);
    });

    test('fromJson with missing/null fields and copyWith', () {
      final parsed = ConversationModel.fromJson({});
      expect(parsed.id, '');
      expect(parsed.userId, isNull);
      expect(parsed.date, isNotNull);
      expect(parsed.summary, '');
      expect(parsed.createdAt, isNotNull);
      expect(parsed.messages, isEmpty);

      final emptyIdConv = ConversationModel(
        id: '',
        date: DateTime.now(),
        summary: '',
        createdAt: DateTime.now(),
      );
      final json = emptyIdConv.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('user_id'), isFalse);

      final modified = emptyIdConv.copyWith(
        id: 'new_id',
        userId: 'user_x',
        date: DateTime(2026, 1, 1),
        summary: '새 요약',
        createdAt: DateTime(2026, 1, 1, 10, 0),
        messages: [],
      );
      expect(modified.id, 'new_id');
      expect(modified.userId, 'user_x');
      expect(modified.summary, '새 요약');

      final unmodified = emptyIdConv.copyWith();
      expect(unmodified.id, emptyIdConv.id);
      expect(unmodified.userId, emptyIdConv.userId);
      expect(unmodified.summary, emptyIdConv.summary);
    });
  });

  group('UserModel Tests', () {
    test('instantiation and fromJson', () {
      final now = DateTime.now();
      final user = UserModel(
        id: 'u123',
        kakaoId: 'k123',
        lineId: 'l123',
        name: '홍길동',
        createdAt: now,
      );

      expect(user.id, 'u123');
      expect(user.kakaoId, 'k123');
      expect(user.lineId, 'l123');
      expect(user.name, '홍길동');
      expect(user.createdAt, now);

      final json = {
        'id': 'u123',
        'kakao_id': 'k123',
        'line_id': 'l123',
        'name': '홍길동',
        'created_at': now.toIso8601String(),
      };

      final parsed = UserModel.fromJson(json);
      expect(parsed.id, 'u123');
      expect(parsed.kakaoId, 'k123');
      expect(parsed.lineId, 'l123');
      expect(parsed.name, '홍길동');
      expect(parsed.createdAt, now);
    });
  });

  group('Env and AiProvider Tests', () {
    test('Env properties return String and AiProvider enum works', () {
      expect(Env.supabaseUrl, isA<String>());
      expect(Env.supabaseAnonKey, isA<String>());
      expect(Env.openAiApiKey, isA<String>());
      expect(Env.geminiApiKey, isA<String>());
      expect(Env.activeAiProvider, equals(AiProvider.openai));
      expect(AiProvider.values.contains(AiProvider.openai), isTrue);
    });
  });
}
