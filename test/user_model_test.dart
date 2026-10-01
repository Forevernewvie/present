import 'package:flutter_test/flutter_test.dart';
import 'package:present_app/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': '123-uuid',
        'kakao_id': 'kakao123',
        'name': 'John',
        'created_at': '2023-10-01T12:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, '123-uuid');
      expect(user.kakaoId, 'kakao123');
      expect(user.lineId, isNull);
      expect(user.name, 'John');
      expect(user.createdAt, DateTime.parse('2023-10-01T12:00:00Z'));
    });

    test('fromJson handles null or missing created_at', () {
      final json = {
        'id': '456-uuid',
      };
      final user = UserModel.fromJson(json);
      expect(user.id, '456-uuid');
      expect(user.createdAt, isNotNull);
    });
  });
}
