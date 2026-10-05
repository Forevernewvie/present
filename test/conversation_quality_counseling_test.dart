import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:present_app/models/chat_message_model.dart';
import 'package:present_app/models/conversation_model.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:present_app/services/interfaces/i_openai_service.dart';
import 'package:present_app/services/interfaces/i_stt_service.dart';
import 'package:present_app/services/interfaces/i_tts_service.dart';
import 'package:present_app/services/interfaces/i_conversation_repository.dart';
import 'package:present_app/services/conversation_repository.dart';

void main() {
  group('🧠 Senior Psychological Counseling & Conversational Quality Tests', () {
    test('1. buildSystemPrompt contains 3-stage counseling protocol and crisis safety', () {
      final promptMom = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: '엄마',
      );

      // 공감 및 감정 미러링 포함 확인
      expect(promptMom.contains('공감과 정서 미러링'), isTrue);
      // 티키타카 열린 질문 포함 확인
      expect(promptMom.contains('티키타카 열린 질문'), isTrue);
      // 위기 개입 및 109 상담전화 안내 지침 포함 확인
      expect(promptMom.contains('109'), isTrue);
      // 엄마 호칭 규칙 준수 확인
      expect(promptMom.contains('"엄마"라는 호칭만 일관되게 사용'), isTrue);

      final promptDad = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: '아빠',
      );
      expect(promptDad.contains('"아빠"라는 호칭만 일관되게 사용'), isTrue);
    });

    test('2. Partner and Neighbor personas enforce active listening and open question ping-pong', () {
      final partnerPrompt = PersonaType.partner.systemPrompt;
      expect(partnerPrompt.contains('감정 경청'), isTrue);
      expect(partnerPrompt.contains('열린 질문'), isTrue);

      final neighborPrompt = PersonaType.neighbor.systemPrompt;
      expect(neighborPrompt.contains('공감대'), isTrue);
      expect(neighborPrompt.contains('일상 질문'), isTrue);
    });

    test('3. VoiceChatNotifier passes aggregated cross-session history to OpenAiService for memory continuity', () async {
      final mockOpenAi = MockQualityOpenAiService();
      final mockStt = MockQualitySttService();
      final mockTts = MockQualityTtsService();
      final mockRepo = MockQualityConversationRepository();

      // 이전 세션 1 (어제 대화)
      mockRepo.localConversations.add(
        ConversationModel(
          id: 'conv_1',
          date: DateTime.now().subtract(const Duration(days: 1)),
          summary: '어제 병원 다녀오신 이야기',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          messages: [
            ChatMessageModel(
              id: 'm1',
              sender: 'user',
              content: '어제 무릎 주사 맞고 왔어',
              createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
            ),
            ChatMessageModel(
              id: 'm2',
              sender: 'ai',
              content: '엄마 주사 맞으시느라 고생하셨어요. 오늘은 좀 어떠세요?',
              createdAt: DateTime.now().subtract(const Duration(days: 1, minutes: 59)),
            ),
          ],
        ),
      );

      // 이전 세션 2 (오늘 아침 대화)
      mockRepo.localConversations.add(
        ConversationModel(
          id: 'conv_2',
          date: DateTime.now(),
          summary: '오늘 아침 안부',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          messages: [
            ChatMessageModel(
              id: 'm3',
              sender: 'user',
              content: '아침에 산책 한 바퀴 돌았지',
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            ),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => VoiceChatNotifier(
            openAiService: mockOpenAi,
            sttService: mockStt,
            ttsService: mockTts,
            repository: mockRepo,
          )),
        ],
      );

      final notifier = container.read(voiceChatProvider.notifier);

      // 사용자가 새 발화를 시작함
      mockStt.simulatedSpeech = '날씨가 참 좋더라고';
      await notifier.toggleRecording(); // 듣기 시작 -> 모의 발화
      // 비동기 AI 처리 완료 대기 (CI 환경에서도 안정적으로 완료 대기)
      for (int i = 0; i < 20; i++) {
        if (mockOpenAi.receivedHistory.length >= 3) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // OpenAiService에 전달된 history 확인: 세션 1과 세션 2의 메시지가 시간순으로 모두 전달되었는가?
      expect(mockOpenAi.receivedHistory.length, 3);
      expect(mockOpenAi.receivedHistory[0].content, '어제 무릎 주사 맞고 왔어');
      expect(mockOpenAi.receivedHistory[1].content, '엄마 주사 맞으시느라 고생하셨어요. 오늘은 좀 어떠세요?');
      expect(mockOpenAi.receivedHistory[2].content, '아침에 산책 한 바퀴 돌았지');
    });
  });
}

class MockQualityOpenAiService implements IOpenAiService {
  List<dynamic> receivedHistory = [];
  String simulatedReply = '어머니 산책 다녀오셔서 기분 좋으셨겠어요! 오늘은 어떤 길로 다녀오셨어요?';

  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    receivedHistory = List.from(history);
    return simulatedReply;
  }
}

class MockQualitySttService implements ISttService {
  String simulatedSpeech = '';
  void Function(String)? _onResult;
  bool _hasSpoken = false;

  @override
  Future<bool> initialize({void Function(String)? onStatus, void Function(dynamic)? onError}) async {
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String text) onResult,
    Duration? pauseFor,
    void Function()? onEmulatorDone,
  }) async {
    _onResult = onResult;
    if (simulatedSpeech.isNotEmpty && !_hasSpoken) {
      _hasSpoken = true;
      _onResult?.call(simulatedSpeech);
      onEmulatorDone?.call();
    }
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class MockQualityTtsService implements ITtsService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class MockQualityConversationRepository implements IConversationRepository {
  @override
  final List<ConversationModel> localConversations = [];

  @override
  List<PendingSyncTurn> get pendingSyncTurns => const [];

  @override
  Future<int> syncPendingTurns() async => 0;

  @override
  Future<void> saveConversationTurn({
    String? userId,
    required String userText,
    required DateTime userTime,
    required String aiText,
    required DateTime aiTime,
  }) async {}

  @override
  Future<List<ConversationModel>> fetchConversations({String? userId}) async {
    return localConversations;
  }

  @override
  void clearLocalCache() {
    localConversations.clear();
  }
}
