import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/env.dart';
import 'providers/router_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/senior_error_fallback_widget.dart';

// coverage:ignore-start
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupGlobalErrorHandlers();

  // 환경변수 동적 로딩: kReleaseMode이거나 --dart-define=ENV=prod 이면 .env.prod, 그 외는 .env.dev
  const envMode = String.fromEnvironment('ENV', defaultValue: '');
  final targetEnv = (kReleaseMode || envMode.toLowerCase() == 'prod') ? '.env.prod' : '.env.dev';

  try {
    await dotenv.load(fileName: targetEnv);
    debugPrint('Successfully loaded environment file: $targetEnv');
  } catch (e) {
    debugPrint('Failed to load $targetEnv, attempting fallback to .env: $e');
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('Successfully loaded fallback environment file: .env');
    } catch (fallbackError) {
      debugPrint('Failed to load fallback .env file: $fallbackError');
    }
  }

  await initializeDateFormatting('ko_KR', null);
  
  // Initialize Kakao & LINE SDK only on mobile platforms
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    try {
      KakaoSdk.init(
        nativeAppKey: '1f20e3601cb54e69eb1fd00f0f68c43b',
      );
    } catch (e) {
      debugPrint('Kakao SDK init error: $e');
    }
    try {
      await LineSDK.instance.setup('2011539378');
    } catch (e) {
      debugPrint('LINE SDK init error: $e');
    }
  }

  // Initialize Supabase with actual keys from Env
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: PresentApp(),
    ),
  );
}
// coverage:ignore-end

class PresentApp extends ConsumerWidget {
  const PresentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Present',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        // 따뜻한 그린 & 베이지 톤 (아리아케어 스타일)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF689F38), // 웜 그린
          background: const Color(0xFFFDFBF7), // 따뜻한 베이지/오프화이트
          surface: const Color(0xFFFFFFFF),
          primary: const Color(0xFF689F38),
        ),
        // 시니어 타겟 큰 글자 테마
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 20, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 18, color: Colors.black87),
          labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
