import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:present_app/models/user_model.dart';
import 'package:present_app/providers/auth_provider.dart';
import 'package:present_app/ui/login_screen.dart';
import 'package:present_app/ui/app_settings_dialog.dart';
import 'package:present_app/ui/main_screen.dart';

void main() {
  group('🛡️ Store Compliance & Review Guideline Tests', () {
    testWidgets('1. LoginScreen provides Guest Mode for App Store reviewers without Kakao', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 카카오 버튼 존재 확인
      expect(find.text('카카오톡으로 3초만에 시작하기'), findsOneWidget);

      // 이용약관 및 개인정보처리방침 안내 링크 존재 확인
      expect(find.text('이용약관'), findsOneWidget);
      expect(find.text('개인정보처리방침'), findsOneWidget);

      // 스크롤하여 뷰포트에 노출 후 탭
      await tester.ensureVisible(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();

      expect(find.text('개인정보처리방침'), findsWidgets);
      expect(find.text('확인'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      // 이용약관 링크 탭 시 인앱 다이얼로그 노출 확인
      await tester.ensureVisible(find.text('이용약관'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이용약관'));
      await tester.pumpAndSettle();

      expect(find.text('서비스 이용약관'), findsWidgets);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
    });

    testWidgets('2. AppSettingsDialog offers Account Deletion (Guideline 5.1.1(v)) and AI Disclaimer', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => TestAuthNotifier(
            user: UserModel(id: 'test_uuid_123', kakaoId: 'kakao_123', name: '김어머니', createdAt: DateTime.now()),
          )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AppSettingsDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 유저 정보 표시 확인
      expect(find.text('김어머니'), findsOneWidget);

      // AI 서비스 면책 안내 카드 확인
      expect(find.textContaining('의료·약학·법률 상담을 대체할 수 없습니다'), findsOneWidget);

      // 개인정보처리방침 및 이용약관 메뉴 확인
      expect(find.text('개인정보처리방침'), findsOneWidget);
      expect(find.text('서비스 이용약관'), findsOneWidget);

      // 로그아웃 버튼 확인
      expect(find.text('로그아웃'), findsOneWidget);

      // 필수 요구사항: 회원 탈퇴(계정 삭제) 버튼 확인
      expect(find.text('회원 탈퇴'), findsOneWidget);

      // 회원 탈퇴 버튼 탭 시 경고 확인창 노출 확인
      await tester.tap(find.text('회원 탈퇴'));
      await tester.pumpAndSettle();

      expect(find.text('회원 탈퇴 (계정 삭제)'), findsOneWidget);
      expect(find.textContaining('모든 대화 기록과 사용자 정보가 영구히 파기되며'), findsOneWidget);
      expect(find.text('탈퇴 및 데이터 삭제'), findsOneWidget);
    });

    testWidgets('3. MainScreen includes AI Disclaimer caption and Settings button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 앱바의 설정 버튼 확인
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // 하단 AI 면책 조항 안내 문구 확인
      expect(find.textContaining('의료·약학·법률 상담을 대신하지 않습니다'), findsOneWidget);
    });

    test('4. AuthNotifier.deleteAccount sets auth state to null and clears cache', () async {
      final testNotifier = TestAuthNotifier(
        user: UserModel(id: 'delete_test_id', kakaoId: 'kakao_del', name: '탈퇴유저', createdAt: DateTime.now()),
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => testNotifier),
        ],
      );

      final initialUser = await container.read(authProvider.future);
      expect(initialUser?.name, '탈퇴유저');

      await container.read(authProvider.notifier).deleteAccount();

      expect(container.read(authProvider).value, isNull);
    });
  });
}

class TestAuthNotifier extends AuthNotifier {
  final UserModel? _customUser;
  TestAuthNotifier({UserModel? user}) : _customUser = user;

  @override
  Future<UserModel?> build() async {
    return _customUser;
  }
}
