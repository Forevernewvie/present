class ChatMessageModel {
  final String id;
  final String? conversationId;
  final String sender; // 'user' | 'ai'
  final String content;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    this.conversationId,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => sender == 'user';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString(),
      sender: json['sender']?.toString() ?? 'user',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      'sender': sender,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
