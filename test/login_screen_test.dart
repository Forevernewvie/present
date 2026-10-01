import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:present_app/ui/login_screen.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('renders Kakao login button and hides Line login button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // '카카오톡으로 3초만에 시작하기' 텍스트 확인
      expect(find.text('카카오톡으로 3초만에 시작하기'), findsOneWidget);

      // 상단 친근한 안내 문구 확인
      expect(find.text('반가워요!\n오늘도 따뜻한 대화를 나눠봐요'), findsOneWidget);

      // '라인으로 시작하기' 텍스트는 숨겨져 있어야 함
      expect(find.text('라인으로 시작하기'), findsNothing);

      // 카카오 로그인 버튼 탭 시도시 크래시 없이 동작
      await tester.tap(find.text('카카오톡으로 3초만에 시작하기'));
      await tester.pump();
    });

    testWidgets('displays loading indicator when initialLoading is true', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(initialLoading: true),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('카카오톡으로 3초만에 시작하기'), findsNothing);
    });
  });
}
