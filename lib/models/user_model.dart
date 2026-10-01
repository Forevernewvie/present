class UserModel {
  final String id;
  final String? kakaoId;
  final String? lineId;
  final String? name;
  final DateTime createdAt;

  UserModel({
    required this.id,
    this.kakaoId,
    this.lineId,
    this.name,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      kakaoId: json['kakao_id']?.toString(),
      lineId: json['line_id']?.toString(),
      name: json['name']?.toString(),
      createdAt: json['created_at'] != null 
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) 
          : DateTime.now(),
    );
  }
}
