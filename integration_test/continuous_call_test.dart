
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:present_app/main.dart';
import 'package:present_app/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:present_app/ui/splash_screen.dart';
import 'package:present_app/ui/login_screen.dart';
import 'package:present_app/ui/main_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Continuous Call Mode UI & State Machine E2E Test', (WidgetTester tester) async {
    try {
      await dotenv.load(fileName: ".env.dev");
    } catch (_) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (_) {}
    }

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;
    final authRes = await supabase.auth.signInAnonymously();
    final userId = authRes.user!.id;

    try {
      await supabase.from('users').upsert({
        'id': userId,
        'kakao_id': 'continuous_e2e_$userId',
        'name': 'Continuous Call Tester',
      }).select();
    } catch (_) {}
    
    await tester.pumpWidget(const ProviderScope(child: PresentApp()));
    
    // SplashScreen에서 auth 상태 확인 및 MainScreen으로 리다이렉트가 완료될 때까지 프레임 펌프
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(MainScreen).evaluate().isNotEmpty) {
        break;
      }
    }
    
    debugPrint('현재 렌더링된 화면 확인:');
    debugPrint(' - SplashScreen: ${find.byType(SplashScreen).evaluate().isNotEmpty}');
    debugPrint(' - LoginScreen: ${find.byType(LoginScreen).evaluate().isNotEmpty}');
    debugPrint(' - MainScreen: ${find.byType(MainScreen).evaluate().isNotEmpty}');
    
    // Wait until text is visible
    for (int i = 0; i < 20; i++) {
       await tester.pump(const Duration(milliseconds: 200));
       debugPrint(' - [Wait $i] MainScreen: ${find.byType(MainScreen).evaluate().isNotEmpty}');
       if (tester.any(find.textContaining('대화를 시작하려면'))) break;
    }
    
    expect(find.textContaining('대화를 시작하려면'), findsWidgets);
    
    final micButton = find.byIcon(Icons.mic);
    expect(micButton, findsOneWidget);
    await tester.tap(micButton);
    await tester.pump(const Duration(seconds: 1));
    
    expect(find.textContaining('대화가 진행 중입니다'), findsWidgets);
    
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(micButton);
    await tester.pump(const Duration(seconds: 1));
    
    expect(find.textContaining('대화를 시작하려면'), findsWidgets);
    debugPrint('✅ [E2E 검증 완료] 통화 시작 -> 연속 대화 진입 -> 통화 종료 파이프라인 정상 작동');
  });
}
