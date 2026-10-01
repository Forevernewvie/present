import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message_model.dart';

class DetailScreen extends StatelessWidget {
  final DateTime date;
  final String summary;
  final List<ChatMessageModel>? initialMessages;

  const DetailScreen({
    super.key,
    required this.date,
    required this.summary,
    this.initialMessages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('yyyy년 MM월 dd일', 'ko_KR').format(date);

    // 기본 시뮬레이션 메시지 (저장된 메시지가 없을 경우의 기본값)
    final baseTime = DateTime(date.year, date.month, date.day, 14, 30);
    final defaultMessages = [
      {
        'sender': 'ai', 
        'text': '안녕하세요! 오늘 하루는 어떠셨나요?', 
        'createdAt': baseTime
      },
      {
        'sender': 'user', 
        'text': '오늘 날씨가 좋아서 집 앞 공원에 산책을 다녀왔지.', 
        'createdAt': baseTime.add(const Duration(minutes: 2))
      },
      {
        'sender': 'ai', 
        'text': '정말 좋으셨겠어요! 공원에는 꽃이 많이 피어있던가요?', 
        'createdAt': baseTime.add(const Duration(minutes: 2, seconds: 15))
      },
      {
        'sender': 'user', 
        'text': '응, 노란 개나리가 예쁘게 피었더라. 기분이 상쾌했어.', 
        'createdAt': baseTime.add(const Duration(minutes: 5))
      },
      {
        'sender': 'ai', 
        'text': '상쾌한 하루를 보내셔서 저도 기분이 좋네요. 내일도 맑은 날씨라고 하니 또 산책 가시면 어떨까요?', 
        'createdAt': baseTime.add(const Duration(minutes: 5, seconds: 30))
      },
    ];

    // 실제 전달받은 DB 메시지가 있으면 해당 메시지와 정밀 타임스탬프를 렌더링
    final List<Map<String, dynamic>> messages = (initialMessages != null && initialMessages!.isNotEmpty)
        ? initialMessages!.map((m) => {
            'sender': m.sender,
            'text': m.content,
            'createdAt': m.createdAt,
          }).toList()
        : defaultMessages;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. 요약본 상단 강조 박스
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      '오늘의 대화 요약',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  summary,
                  style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
          
          const Divider(thickness: 1, height: 1),

          // 2. 카카오톡 스타일 대화 전문 나열 (정밀 타임스탬프 포함)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg['sender'] == 'user';
                final text = msg['text'] as String;
                final createdAt = msg['createdAt'] as DateTime;
                
                // 오전/오후 h:mm 포맷
                final timeStr = DateFormat('a h:mm', 'ko_KR').format(createdAt);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // AI 아바타 (왼쪽)
                      if (!isUser) ...[
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(Icons.support_agent, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // 유저일 경우 말풍선 왼쪽에 시간 표시
                      if (isUser) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0, bottom: 4.0),
                          child: Text(
                            timeStr,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],

                      // 말풍선 본문
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                          decoration: BoxDecoration(
                            color: isUser ? theme.colorScheme.secondaryContainer : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
                              bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.4),
                          ),
                        ),
                      ),
                      
                      // AI일 경우 말풍선 오른쪽에 시간 표시
                      if (!isUser) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0, bottom: 4.0),
                          child: Text(
                            timeStr,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
