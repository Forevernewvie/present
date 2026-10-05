import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/chat_message_model.dart';
import 'cancellation_token.dart';
import 'interfaces/i_openai_service.dart';

class OpenAiService implements IOpenAiService {
  final String? _apiKeyOverride;
  final http.Client _client;
  final bool _hasCustomClient;

  OpenAiService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _hasCustomClient = client != null,
        _apiKeyOverride = apiKey;

  String get _endpoint => Env.activeAiProvider == AiProvider.gemini
      ? 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
      : 'https://api.openai.com/v1/chat/completions';

  String get _model => Env.activeAiProvider == AiProvider.gemini
      ? 'gemini-flash-lite-latest'
      : 'gpt-4o-mini';

  String get _apiKey {
    if (_apiKeyOverride != null) return _apiKeyOverride;
    return Env.activeAiProvider == AiProvider.gemini ? Env.geminiApiKey : Env.openAiApiKey;
  }
  
  bool get hasKey => _apiKey.trim().isNotEmpty;

  // [페르소나 및 호칭 설정]
  static PersonaType activePersona = PersonaType.child;
  static String activeParentTitle = '엄마';

  static String buildSystemPrompt({PersonaType? persona, String? parentTitle}) {
    final p = persona ?? activePersona;
    final title = (parentTitle ?? activeParentTitle) == '아빠' ? '아빠' : '엄마';

    if (p == PersonaType.child) {
      final String titleRule;
      if (title == '엄마') {
        titleRule = '2. [호칭 규칙]: 사용자는 어머니입니다. 부모님을 부를 때는 반드시 "엄마"라는 호칭만 일관되게 사용하세요. 절대 "아빠", "어르신", "할머니", "사용자님"이라고 부르지 마세요. 대화 도중 호칭이 변경되었더라도 이전 대화 내용에 구애받지 말고 이번 답변부터 즉시 "엄마"라고 불러야 합니다.';
      } else {
        titleRule = '2. [호칭 규칙]: 사용자는 아버지입니다. 부모님을 부를 때는 반드시 "아빠"라는 호칭만 일관되게 사용하세요. 절대 "엄마", "어르신", "할아버지", "사용자님"이라고 부르지 마세요. 대화 도중 호칭이 변경되었더라도 이전 대화 내용에 구애받지 말고 이번 답변부터 즉시 "아빠"라고 불러야 합니다.';
      }

      return '''
당신은 50~60대 부모님의 일상과 마음 건강을 살갑게 보살피는 든든하고 다정한 20~30대 자녀(아들/딸)이자 전문적 정서 상담 파트너입니다.

[핵심 상담 대화 3원칙 - 쌍방향 핑퐁 소통 보장]:
1. [공감과 정서 미러링]: 부모님의 말씀에 담긴 감정(기쁨, 외로움, 피로, 서운함 등)을 먼저 따뜻하게 알아차리고 공감하세요. 성급한 훈계나 영혼 없는 긍정("힘내세요")은 피하고, 마음을 온전히 수용하세요.
$titleRule
3. [티키타카 열린 질문]: 대화가 끊기지 않고 자연스럽게 이어지도록, 답변의 끝은 반드시 부모님이 편안하게 대답하실 수 있는 "다정한 열린 질문 1개"로 맺으세요.
4. [음성 호흡 최적화]: 음성 통화(TTS)로 청취되므로, 총 2~3문장(공감 1~2문장 + 질문 1문장)으로 간결하고 또렷하게 말씀하세요.
5. [안전 및 위기 개입]: 부모님이 극심한 우울, 삶의 허무, 죽음이나 고독을 표현하실 경우 깊은 애정과 함께 안심시켜 드리고 전문 상담전화(109 또는 1577-0199)를 다정하게 안내하세요. 가슴 통증 등 응급 질환 징후 시 즉시 119 연락을 권유하세요.
6. [금지 사항]: 이모티콘, 특수기호(*, # 등), 영어 단어, 반말은 절대 쓰지 마세요. 시니어를 어린아이 취급하지 마세요.
''';
    } else {
      return p.systemPrompt;
    }
  }

  /// 사용자의 말과 최근 대화 기록을 기반으로 OpenAI GPT 응답을 생성합니다.
  @override
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    String? parentTitle,
    CancellationToken? cancelToken,
  }) async {
    if (!hasKey) {
      throw Exception(
        'API 키가 없습니다.\nlib/config/env.dart 파일에 현재 설정된 AI의 키를 입력해 주세요.',
      );
    }

    PersonaType targetPersona = activePersona;
    for (final p in PersonaType.values) {
      if (p.name == persona) {
        targetPersona = p;
        break;
      }
    }

    final systemPrompt = buildSystemPrompt(
      persona: targetPersona,
      parentTitle: parentTitle,
    );
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // 최근 최대 4개의 이전 대화 맥락 포함 (모바일/음성 최적화)
    messages.addAll(history.skip(history.length > 4 ? history.length - 4 : 0).map((m) {
      if (m is ChatMessageModel) {
        return {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.content,
        };
      } else if (m is Map) {
        return {
          'role': (m['sender'] == 'user' || m['isUser'] == true) ? 'user' : 'assistant',
          'content': m['content']?.toString() ?? '',
        };
      }
      return {
        'role': 'user',
        'content': m.toString(),
      };
    }));

    messages.add({'role': 'user', 'content': userMessage});

    if (cancelToken?.isCancelled == true) {
      throw CancelledException('AI 요청이 사용자에 의해 취소되었습니다.');
    }

    final clientToUse = (cancelToken != null && !_hasCustomClient) ? http.Client() : _client;
    cancelToken?.onCancel(() {
      try {
        if (!_hasCustomClient) {
          clientToUse.close();
        }
      } catch (_) {}
    });

    int attempt = 0;
    const int maxRetries = 2;

    try {
      while (true) {
        if (cancelToken?.isCancelled == true) {
          throw CancelledException('AI 요청이 사용자에 의해 취소되었습니다.');
        }

        try {
          final response = await clientToUse.post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${_apiKey.trim()}',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 150,
            }),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
            debugPrint('OpenAI Raw Response: $decoded');
            
            final choices = decoded['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final firstChoice = choices[0];
              
              if (firstChoice is Map && firstChoice['message'] is Map) {
                 final reply = firstChoice['message']['content'] as String? ?? '';
                 return reply.trim();
              } else if (firstChoice is Map && firstChoice['message'] is String) {
                 return (firstChoice['message'] as String).trim();
              } else if (firstChoice is Map && firstChoice['text'] != null) {
                 return (firstChoice['text'] as String).trim();
              }
            }
            throw Exception('응답 형식이 올바르지 않습니다. Raw: $decoded');
          } else {
            debugPrint('OpenAI Error Raw Body: ${response.body}');
            final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
            String errorMsg = 'API 호출 실패 (${response.statusCode})';
            if (errorJson is Map && errorJson['error'] is Map) {
              errorMsg = errorJson['error']['message'] ?? errorMsg;
            } else if (errorJson is Map && errorJson['error'] is String) {
              errorMsg = errorJson['error'];
            }
            debugPrint('OpenAI API Error: $errorMsg');
            
            if (response.statusCode == 429) {
              throw Exception('할당량 초과(429) - $errorMsg');
            } else if (response.statusCode >= 500) {
              if (attempt < maxRetries && cancelToken?.isCancelled != true) {
                attempt++;
                debugPrint('일시적 서버 에러(5xx) 감지 - $attempt/$maxRetries 재시도 중...');
                await Future.delayed(Duration(milliseconds: 100 * attempt));
                continue;
              }
              throw Exception('서버 에러(5xx) - $errorMsg');
            }
            throw Exception('OpenAI 오류: $errorMsg');
          }
        } on TimeoutException {
          debugPrint('OpenAiService Timeout');
          if (attempt < maxRetries && cancelToken?.isCancelled != true) {
            attempt++;
            debugPrint('네트워크 응답 지연 감지 - $attempt/$maxRetries 재시도 중...');
            await Future.delayed(Duration(milliseconds: 100 * attempt));
            continue;
          }
          throw Exception('네트워크 지연으로 API 응답 시간이 초과되었습니다.');
        } catch (e) {
          if (cancelToken?.isCancelled == true || e is CancelledException) {
            throw CancelledException('AI 요청이 사용자에 의해 취소되었습니다.');
          }
          if (e.toString().contains('네트워크 지연') || e.toString().contains('할당량 초과') || e.toString().contains('서버 에러') || e.toString().contains('OpenAI 오류')) {
            rethrow;
          }
          debugPrint('OpenAiService Exception: $e');
          if (attempt < maxRetries && cancelToken?.isCancelled != true) {
            attempt++;
            debugPrint('일시적 네트워크 예외 감지 - $attempt/$maxRetries 재시도 중...');
            await Future.delayed(Duration(milliseconds: 100 * attempt));
            continue;
          }
          throw Exception('네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.');
        }
      }
    } finally {
      if (cancelToken != null && !_hasCustomClient) {
        try {
          clientToUse.close();
        } catch (_) {}
      }
    }
  }
}

enum PersonaType {
  partner(
    '스마트 라이프 파트너', 
    '''
당신은 50~60대 신중년(액티브 시니어)의 건강한 라이프스타일과 멘탈 케어를 함께하는 지적이고 다정한 라이프 파트너이자 AI 상담 동반자 'Present'입니다.
규칙:
1. 사용자를 절대 "어르신", "할머니", "할아버지"로 부르지 마세요. 인생의 전성기를 누리는 지적이고 활기찬 신중년으로 존중하세요.
2. [상담 원칙]: 감정 경청(Active Listening) ➔ 지지적 피드백(Validation) ➔ 열린 질문(Open Question)의 3단계 흐름을 지키세요.
3. 사용자가 자신의 일상, 취미, 건강 루틴에 대해 계속 이야기하고 싶도록 흥미와 호기심을 갖고 질문을 건네세요.
4. 음성 통화이므로 2~3문장으로 간결하고 품격 있는 해요체 존댓말을 사용하세요.
5. 특수기호나 이모티콘은 절대 사용하지 마세요.
'''
  ),
  neighbor(
    '친근한 동년배 친구', 
    '''
당신은 50~60대 사용자와 일상의 기쁨과 고민을 격의 없이 나누는 따뜻하고 배려 깊은 동년배 친구입니다.
규칙:
1. 사용자를 나이 든 노인 취급하지 말고, 같은 시대를 살아가는 든든한 동반자이자 편안한 친구처럼 대하세요.
2. "그 마음 저도 잘 알지요", "정말 애쓰셨어요"처럼 깊은 공감대를 형성하세요.
3. 말문이 막히지 않도록 대화 끝에 소소한 일상 질문(오늘 드신 차, 산책길, 가족 이야기 등)을 다정하게 건네세요.
4. 음성 통화에 맞추어 2~3문장으로 리듬감 있게 대화하세요.
5. 특수기호나 이모티콘은 사용하지 마세요.
'''
  ),
  child(
    '다정한 2030 자녀', 
    '''
당신은 50~60대 부모님의 일상과 마음 건강을 살갑게 보살피는 든든하고 다정한 20~30대 자녀입니다.
규칙:
1. 부모님의 감정을 먼저 깊이 공감하고 인정하세요.
2. 사용자를 절대 "어르신", "할머니", "할아버지"로 부르지 마세요.
3. 대화가 자연스럽게 이어지도록 매 턴마다 다정하고 부담 없는 열린 질문 1개로 마무리하세요.
4. 총 2~3문장의 명료한 호흡을 유지하세요.
5. 이모티콘이나 특수기호는 일절 쓰지 마세요.
'''
  );

  static const PersonaType grandchild = partner;

  final String displayName;
  final String systemPrompt;
  const PersonaType(this.displayName, this.systemPrompt);
}
