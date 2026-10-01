import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import 'interfaces/i_conversation_repository.dart';

class PendingSyncTurn {
  final String userId;
  final String userText;
  final DateTime userTime;
  final String aiText;
  final DateTime aiTime;

  PendingSyncTurn({
    required this.userId,
    required this.userText,
    required this.userTime,
    required this.aiText,
    required this.aiTime,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userText': userText,
    'userTime': userTime.toIso8601String(),
    'aiText': aiText,
    'aiTime': aiTime.toIso8601String(),
  };

  factory PendingSyncTurn.fromJson(Map<String, dynamic> json) => PendingSyncTurn(
    userId: json['userId'] as String? ?? '',
    userText: json['userText'] as String? ?? '',
    userTime: DateTime.tryParse(json['userTime'] as String? ?? '') ?? DateTime.now(),
    aiText: json['aiText'] as String? ?? '',
    aiTime: DateTime.tryParse(json['aiTime'] as String? ?? '') ?? DateTime.now(),
  );
}

class ConversationRepository implements IConversationRepository {
  static const String _keyPendingTurns = 'offline_pending_sync_turns';
  final SupabaseClient? _customClient;

  ConversationRepository({SupabaseClient? supabaseClient}) : _customClient = supabaseClient {
    _restorePersistedPendingTurns();
  }

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // 로컬 세션 캐시 (DB 오프라인 또는 테이블 미생성 시에도 즉시 UI에 반영되도록 보장)
  final List<ConversationModel> _localConversations = [];

  @override
  List<ConversationModel> get localConversations => List.unmodifiable(_localConversations);

  // 오프라인 동기화 대기 큐
  final List<PendingSyncTurn> _pendingSyncTurns = [];

  @override
  List<PendingSyncTurn> get pendingSyncTurns => List.unmodifiable(_pendingSyncTurns);

  Future<void> _restorePersistedPendingTurns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_keyPendingTurns);
      if (savedJson != null && savedJson.isNotEmpty) {
        final decoded = jsonDecode(savedJson) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final turn = PendingSyncTurn.fromJson(item);
            if (!_pendingSyncTurns.any((t) => t.userTime == turn.userTime && t.userId == turn.userId)) {
              _pendingSyncTurns.add(turn);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistPendingTurns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = _pendingSyncTurns.map((t) => t.toJson()).toList();
      await prefs.setString(_keyPendingTurns, jsonEncode(listJson));
    } catch (_) {}
  }

  void _addPendingTurn(PendingSyncTurn turn) {
    _pendingSyncTurns.add(turn);
    unawaited(_persistPendingTurns());
  }

  void _removePendingTurn(PendingSyncTurn turn) {
    _pendingSyncTurns.remove(turn);
    unawaited(_persistPendingTurns());
  }

  /// 계정 전환이나 로그아웃 시 메모리 캐시 및 대기 큐를 완전히 초기화합니다.
  @override
  void clearLocalCache() {
    _localConversations.clear();
    _pendingSyncTurns.clear();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keyPendingTurns);
    }).catchError((_) {});
  }

  /// 한 턴의 대화(사용자 발화 + AI 응답)를 각각의 정밀 타임스탬프와 함께 DB에 영구 저장합니다.
  @override
  Future<void> saveConversationTurn({
    required String? userId,
    required String userText,
    required DateTime userTime,
    required String aiText,
    required DateTime aiTime,
  }) async {
    final now = DateTime.now();
    final today = DateTime(userTime.year, userTime.month, userTime.day);
    final todayStr = today.toIso8601String().split('T')[0];

    final userMsg = ChatMessageModel(
      id: 'local_user_${userTime.millisecondsSinceEpoch}',
      sender: 'user',
      content: userText,
      createdAt: userTime,
    );

    final aiMsg = ChatMessageModel(
      id: 'local_ai_${aiTime.millisecondsSinceEpoch}',
      sender: 'ai',
      content: aiText,
      createdAt: aiTime,
    );

    // 가장 최신 대화방 찾기 (오늘 날짜면    // 1 Day = 1 Room: 오늘 날짜와 일치하는 방이 있는지 확인
    int existingIndex = _localConversations.indexWhere((c) {
      return c.date.year == today.year &&
             c.date.month == today.month &&
             c.date.day == today.day;
    });
    bool isNewConversation = existingIndex == -1;
    String? currentConvId = isNewConversation ? null : _localConversations[existingIndex].id;

    // 임시 ID (새 방일 경우)
    final tempId = 'conv_${now.millisecondsSinceEpoch}';

    // 1. 로컬 캐시 즉시 업데이트
    if (!isNewConversation && existingIndex >= 0) {
      final existing = _localConversations[existingIndex];
      _localConversations[existingIndex] = existing.copyWith(
        messages: [...existing.messages, userMsg, aiMsg],
      );
    } else {
      // 오늘 날짜의 첫 대화이므로 새 방 생성
      // 첫 마디를 임시 요약(제목)으로 사용
      final tempSummary = userText.length > 15 ? '${userText.substring(0, 15)}...' : userText;
      _localConversations.insert(
        0,
        ConversationModel(
          id: tempId,
          userId: userId,
          date: today,
          summary: tempSummary,
          createdAt: now,
          messages: [userMsg, aiMsg],
        ),
      );
      if (_localConversations.length > 50) {
        _localConversations.removeRange(50, _localConversations.length);
      }
    }

    // 2. Supabase DB 저장 시도
    final client = _supabase;
    if (client == null || userId == null || userId.isEmpty) {
      debugPrint('Supabase 미초기화 또는 userId 부재로 로컬 상태만 유지합니다.');
      if (userId != null && userId.isNotEmpty) {
        _addPendingTurn(PendingSyncTurn(
          userId: userId,
          userText: userText,
          userTime: userTime,
          aiText: aiText,
          aiTime: aiTime,
        ));
      }
      return;
    }

    try {
      String conversationId;
      if (isNewConversation) {
        // 새 방 Insert
        final tempSummary = userText.length > 15 ? '${userText.substring(0, 15)}...' : userText;
        final insertedConv = await client
            .from('conversations')
            .insert({
              'user_id': userId,
              'date': todayStr,
              'summary': tempSummary,
              'created_at': now.toUtc().toIso8601String(), // KST 문제 해결을 위해 명시적 UTC 변환
            })
            .select()
            .single()
            .timeout(const Duration(seconds: 10));
            
        conversationId = insertedConv['id'].toString();
        
        // 임시 ID로 생성된 로컬 방을 실제 DB ID로 교체
        final idx = _localConversations.indexWhere((c) => c.id == tempId);
        if (idx != -1) {
          _localConversations[idx] = _localConversations[idx].copyWith(id: conversationId);
        }
      } else {
        // 기존 방 재사용
        conversationId = currentConvId!;
      }

      // 두 개의 메시지 Insert
      await client.from('messages').insert([
        {
          'conversation_id': conversationId,
          'sender': 'user',
          'content': userText,
          'created_at': userTime.toUtc().toIso8601String(),
        },
        {
          'conversation_id': conversationId,
          'sender': 'ai',
          'content': aiText,
          'created_at': aiTime.toUtc().toIso8601String(),
        }
      ]).timeout(const Duration(seconds: 10));

      debugPrint('Supabase 대화 저장 완료: conversationId=$conversationId (isNew: $isNewConversation)');
    } on TimeoutException {
      debugPrint('Supabase 저장 타임아웃 (10초 초과): 네트워크 상태를 확인하세요. 대기 큐에 보관합니다.');
      _addPendingTurn(PendingSyncTurn(
        userId: userId,
        userText: userText,
        userTime: userTime,
        aiText: aiText,
        aiTime: aiTime,
      ));
    } catch (e) {
      if (e is PostgrestException) {
        debugPrint('Supabase 저장 DB 오류 (상태코드: ${e.code}): ${e.message}');
      } else {
        debugPrint('Supabase 저장 중 예외 발생 (테이블 구조 등 확인 필요): $e');
      }
      _addPendingTurn(PendingSyncTurn(
        userId: userId,
        userText: userText,
        userTime: userTime,
        aiText: aiText,
        aiTime: aiTime,
      ));
    }
  }

  /// 오프라인 또는 네트워크 장애로 인해 대기 중이던 대화 턴들을 Supabase DB에 일괄 동기화합니다.
  @override
  Future<int> syncPendingTurns() async {
    final client = _supabase;
    if (client == null || _pendingSyncTurns.isEmpty) return 0;

    int syncedCount = 0;
    final toSync = List<PendingSyncTurn>.from(_pendingSyncTurns);

    for (final turn in toSync) {
      try {
        final userTime = turn.userTime;
        final today = DateTime(userTime.year, userTime.month, userTime.day);
        final todayStr = today.toIso8601String().split('T')[0];
        final now = DateTime.now();

        // 기존 방이 있는지 확인
        final existingRooms = await client
            .from('conversations')
            .select('id')
            .eq('user_id', turn.userId)
            .eq('date', todayStr)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        String conversationId;
        if (existingRooms != null && existingRooms['id'] != null) {
          conversationId = existingRooms['id'].toString();
        } else {
          final tempSummary = turn.userText.length > 15
              ? '${turn.userText.substring(0, 15)}...'
              : turn.userText;
          final insertedConv = await client
              .from('conversations')
              .insert({
                'user_id': turn.userId,
                'date': todayStr,
                'summary': tempSummary,
                'created_at': now.toUtc().toIso8601String(),
              })
              .select()
              .single()
              .timeout(const Duration(seconds: 10));
          conversationId = insertedConv['id'].toString();
        }

        await client.from('messages').insert([
          {
            'conversation_id': conversationId,
            'sender': 'user',
            'content': turn.userText,
            'created_at': turn.userTime.toUtc().toIso8601String(),
          },
          {
            'conversation_id': conversationId,
            'sender': 'ai',
            'content': turn.aiText,
            'created_at': turn.aiTime.toUtc().toIso8601String(),
          }
        ]).timeout(const Duration(seconds: 10));

        _removePendingTurn(turn);
        syncedCount++;
      } catch (e) {
        debugPrint('오프라인 대기 큐 동기화 중단: $e');
        break;
      }
    }
    return syncedCount;
  }

  /// 특정 날짜나 전체 대화 목록을 가져옵니다.
  @override
  Future<List<ConversationModel>> fetchConversations({required String? userId}) async {
    final client = _supabase;
    if (client == null || userId == null || userId.isEmpty) {
      return _localConversations;
    }

    // 미동기화 턴이 있다면 동기화 먼저 시도
    if (_pendingSyncTurns.isNotEmpty) {
      await syncPendingTurns();
    }

    try {
      final data = await client
          .from('conversations')
          .select('*, messages(*)')
          .eq('user_id', userId)
          .order('date', ascending: false).order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final list = (data as List<dynamic>).map((item) {
        final rawMessages = item['messages'] as List<dynamic>? ?? [];
        final messages = rawMessages
            .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return ConversationModel.fromJson(item as Map<String, dynamic>, messages: messages);
      }).toList();

      // 로컬에만 있는 미동기화 대화방 보존 (현재 사용자의 대화방만 안전하게 격리 필터링)
      final remoteIds = list.map((c) => c.id).toSet();
      final unsyncedLocal = _localConversations
          .where((c) => c.userId == userId && !remoteIds.contains(c.id))
          .toList();

      _localConversations.clear();
      final combined = [...unsyncedLocal, ...list];
      combined.sort((a, b) => b.date.compareTo(a.date));

      if (combined.isNotEmpty) {
        final limitedList = combined.take(50).toList();
        _localConversations.addAll(limitedList);
      }
      return _localConversations;
    } on TimeoutException {
      debugPrint('Supabase 조회 타임아웃 (10초 초과): 네트워크 상태를 확인하세요. 로컬 캐시를 유지합니다.');
      return _localConversations;
    } catch (e) {
      if (e is PostgrestException) {
        debugPrint('Supabase 조회 DB 오류 (상태코드: ${e.code}): ${e.message}');
      } else {
        debugPrint('Supabase 조회 중 예외 발생: $e');
      }
      return _localConversations;
    }
  }
}
