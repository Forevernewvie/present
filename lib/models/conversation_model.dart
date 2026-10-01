import 'chat_message_model.dart';

class ConversationModel {
  final String id;
  final String? userId;
  final DateTime date;
  final String summary;
  final DateTime createdAt;
  final List<ChatMessageModel> messages;

  ConversationModel({
    required this.id,
    this.userId,
    required this.date,
    required this.summary,
    required this.createdAt,
    this.messages = const [],
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json, {List<ChatMessageModel>? messages}) {
    return ConversationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      date: json['date'] != null
          ? (DateTime.tryParse(json['date'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      summary: json['summary']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      messages: messages ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (userId != null) 'user_id': userId,
      'date': DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0],
      'summary': summary,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ConversationModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? summary,
    DateTime? createdAt,
    List<ChatMessageModel>? messages,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }
}
