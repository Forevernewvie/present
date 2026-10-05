import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/openai_service.dart';
import '../services/tts_service.dart';
import '../services/conversation_repository.dart';
import '../services/interfaces/i_openai_service.dart';
import '../services/interfaces/i_tts_service.dart';
import '../services/interfaces/i_stt_service.dart';
import '../services/interfaces/i_conversation_repository.dart';
import '../services/stt_service.dart';
import '../services/cancellation_token.dart';
import '../models/chat_message_model.dart';
import 'auth_provider.dart';
import 'conversation_list_provider.dart';
import 'settings_provider.dart';

enum VoiceChatStatus {
  idle,       // 대기 상태 ("말씀을 원하시면 버튼을 눌러주세요")
  recording,  // 녹음 중 ("말씀을 마치셨으면 한 번 더 눌러주세요")
  thinking,   // AI 응답 대기 (터치 잠금, "답변을 생각하고 있어요...")
  speaking,   // AI 음성 발화 (터치 잠금, "Present가 말씀드리고 있어요...")
}

class VoiceChatState {
  final VoiceChatStatus status;
  final String recognizedText;
  final String aiResponse;
  final String? errorMessage;
  final DateTime? userSpeechTime;
  final DateTime? aiResponseTime;

  const VoiceChatState({
    this.status = VoiceChatStatus.idle,
    this.recognizedText = '',
    this.aiResponse = '',
    this.errorMessage,
    this.userSpeechTime,
    this.aiResponseTime,
  });

  bool get isCallActive => status != VoiceChatStatus.idle;

  VoiceChatState copyWith({
    VoiceChatStatus? status,
    String? recognizedText,
    String? aiResponse,
    String? errorMessage,
    bool clearError = false,
    DateTime? userSpeechTime,
    DateTime? aiResponseTime,
  }) {
    return VoiceChatState(
      status: status ?? this.status,
      recognizedText: recognizedText ?? this.recognizedText,
      aiResponse: aiResponse ?? this.aiResponse,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userSpeechTime: userSpeechTime ?? this.userSpeechTime,
      aiResponseTime: aiResponseTime ?? this.aiResponseTime,
    );
  }
}

class VoiceChatNotifier extends Notifier<VoiceChatState> {
  final ISttService _sttService;
  final IOpenAiService _openAiService;
  final ITtsService _ttsService;
  final IConversationRepository _repository;
  CancellationToken? _currentAiCancelToken;

  bool _isSpeechInitialized = false;

  VoiceChatNotifier({
    SpeechToText? speech,
    IOpenAiService? openAiService,
    ITtsService? ttsService,
    IConversationRepository? repository,
    ISttService? sttService,
  })  : _sttService = sttService ?? SttService(speech: speech),
        _openAiService = openAiService ?? OpenAiService(),
        _ttsService = ttsService ?? TtsService(),
        _repository = repository ?? ConversationRepository();

  IConversationRepository get repository => _repository;

  @override
  VoiceChatState build() {
    ref.onDispose(() {
      _sttService.dispose();
      _ttsService.dispose();
    });
    return const VoiceChatState();
  }

  /// 마이크 버튼 토글 (시작 ➔ 연속 대화 루프 ➔ 종료)
  Future<void> toggleRecording() async {
    if (state.isCallActive) {
      await _endCall();
    } else {
      await _startListeningTurn();
    }
  }

  /// 강제로 통화(대화)를 종료합니다.
  Future<void> _endCall() async {
    _currentAiCancelToken?.cancel();
    _currentAiCancelToken = null;
    try {
      await _sttService.stop();
    } catch (_) {}
    try {
      await _ttsService.stop();
    } catch (_) {}

    state = state.copyWith(
      status: VoiceChatStatus.idle,
      recognizedText: '',
      aiResponse: '',
    );
  }

  /// 앱 백그라운드 전환, 전화 수신, 화면 잠금 등 OS 인터럽트 발생 시 오디오 세션과 타이머를 안전하게 정지합니다.
  Future<void> handleLifecyclePause() async {
    if (state.isCallActive) {
      debugPrint('오디오 인터럽트/백그라운드 전환 감지: 마이크 및 음성 서비스 안전 종료');
      await _endCall();
    }
  }

  /// 전화 수신, 보이스톡, 타 오디오 앱 간섭 등 하드웨어 오디오 포커스 상실 시 안전하게 정지
  Future<void> handleAudioInterruption({String? reason}) async {
    if (state.isCallActive) {
      debugPrint('오디오 인터럽트 감지: ${reason ?? "오디오 포커스 상실"}');
      await _endCall();
      state = state.copyWith(
        errorMessage: reason ?? '전화 수신 또는 다른 앱의 오디오 사용으로 대화가 잠시 멈췄습니다. 다시 통화하려면 마이크를 눌러주세요.',
      );
    }
  }

  /// AI 턴이 끝나고 사용자의 말을 듣기 시작합니다. (루프의 시작점)
  Future<void> _startListeningTurn() async {
    // 만약 그 사이에 통화가 종료되었다면 중단
    if (!state.isCallActive && state.status != VoiceChatStatus.idle) return;

    state = state.copyWith(
      status: VoiceChatStatus.recording,
      recognizedText: '',
      aiResponse: '',
      clearError: true,
    );

    try {
      if (!_isSpeechInitialized) {
        await _sttService.initialize(
          onStatus: (s) {
            debugPrint('STT Status: $s');
            if (s == 'done' || s == 'notListening') {
               if (state.status == VoiceChatStatus.recording) {
                 _stopAndProcessSpeech();
               }
            }
          },
          onError: (e) {
            debugPrint('STT Error: $e');
            if (state.status == VoiceChatStatus.recording) {
               _stopAndProcessSpeech();
            }
          },
        );
        _isSpeechInitialized = true;
      }
    } catch (e) {
      debugPrint('STT init exception: $e');
    }

    _sttService.listen(
      onResult: (text) {
        if (state.status == VoiceChatStatus.recording) {
          state = state.copyWith(recognizedText: text);
        }
      },
      pauseFor: const Duration(seconds: 2),
      onEmulatorDone: () {
        if (state.status == VoiceChatStatus.recording) {
          _stopAndProcessSpeech();
        }
      },
    );
  }

  /// 사용자의 말이 끝나면 AI로 넘기고 답변을 듣습니다.
  Future<void> _stopAndProcessSpeech() async {
    if (state.status != VoiceChatStatus.recording) return; // 중복 호출 방지

    try {
      await _sttService.stop();
    } catch (_) {}

    String userText = state.recognizedText.trim();
    
    // [시뮬레이터 개런티용 코드] 마이크 연동 문제로 인식이 안 됐을 때 강제로 테스트 문장을 집어넣습니다.
    // 음성 인식이 비어있는 경우
    if (userText.isEmpty) {
      debugPrint('음성 인식이 비어있습니다. 다시 듣기를 시작합니다.');
      // 아무 말도 하지 않은 것이므로 조용히 다시 듣기 루프 재시작
      if (state.isCallActive) {
        _startListeningTurn();
      }
      return;
    }

    // 1. 상태를 'thinking'으로 전환
    final userTime = DateTime.now();
    state = state.copyWith(
      status: VoiceChatStatus.thinking,
      userSpeechTime: userTime,
    );

    final currentUser = ref.read(authProvider).asData?.value;
    final userId = currentUser?.id;

    // 2. OpenAI GPT 응답 요청 (취소 토큰 연동)
    String reply = '';
    DateTime aiTime;

    final cancelToken = CancellationToken();
    _currentAiCancelToken = cancelToken;

    // 최근 세션들 전체에서 최근 대화 메시지들을 취합하여 맥락 연속성 보장
    final allRecentMessages = <ChatMessageModel>[];
    for (final conv in _repository.localConversations) {
      allRecentMessages.addAll(conv.messages);
    }
    allRecentMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final recentHistory = allRecentMessages.length > 8
        ? allRecentMessages.sublist(allRecentMessages.length - 8)
        : allRecentMessages;

    final settings = ref.read(settingsProvider);
    try {
      reply = await _openAiService.getAiReply(
        userMessage: userText,
        history: recentHistory,
        persona: settings.persona.name,
        parentTitle: settings.parentTitle,
        cancelToken: cancelToken,
      );
      aiTime = DateTime.now();
    } catch (e) {
      aiTime = DateTime.now();
      if (!ref.mounted) return;
      if (e is CancelledException || cancelToken.isCancelled) {
        debugPrint('AI 요청 취소 감지됨 - 추가 처리 중단');
        return;
      }
      
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('api key') || errorStr.contains('키가') || errorStr.contains('missing') || errorStr.contains('apikey')) {
        reply = 'API 키가 아직 설정되지 않았습니다. 환경 설정 파일에 키를 입력해 주세요.';
      } else if (errorStr.contains('429') || errorStr.contains('quota') || errorStr.contains('rate limit')) {
        reply = '질문이 너무 많아서 잠깐 숨을 고르고 있어요! 1분만 쉬었다가 다시 말씀해 주세요.';
      } else {
        reply = '죄송해요, 잠시 연결이 원활하지 않아요. 다시 말씀해 주시겠어요?';
      }
      
      state = state.copyWith(
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
    } finally {
      if (_currentAiCancelToken == cancelToken) {
        _currentAiCancelToken = null;
      }
    }

    // 통화가 도중에 취소되었거나 provider가 dispose 되었는지 확인
    if (!ref.mounted || !state.isCallActive) return;

    // 3. 상태를 'speaking'으로 전환
    state = state.copyWith(
      status: VoiceChatStatus.speaking,
      aiResponse: reply,
      aiResponseTime: aiTime,
    );

    // 4. Supabase DB 저장
    await _repository.saveConversationTurn(
      userId: userId,
      userText: userText,
      userTime: userTime,
      aiText: reply,
      aiTime: aiTime,
    );
    
    if (!ref.mounted) return;
    ref.read(conversationListProvider.notifier).forceUpdate(_repository.localConversations);

    // 통화가 도중에 취소되었는지 확인
    if (!ref.mounted || !state.isCallActive) return;

    // 5. 음성(TTS) 재생
    try {
      await _ttsService.speak(reply);
      // TTS의 마지막 잔향이 잘리지 않도록 마이크를 다시 켜기 전에 약간의 여유(0.8초)를 줍니다.
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      debugPrint('TTS 재생 오류: $e');
    }

    // 통화가 도중에 취소되었는지 확인
    if (!ref.mounted || !state.isCallActive) return;

    // 6. AI 답변이 끝났으므로 핑퐁 대화를 위해 '다시 듣기' 루프로 자동 진입!
    _startListeningTurn();
  }
}

final voiceChatProvider = NotifierProvider.autoDispose<VoiceChatNotifier, VoiceChatState>(() => VoiceChatNotifier());

final conversationRepositoryProvider = Provider.autoDispose<IConversationRepository>((ref) {
  return ref.watch(voiceChatProvider.notifier).repository;
});
