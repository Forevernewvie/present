import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AiProvider { openai, gemini }

class Env {
  static String get supabaseUrl => dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] ?? '' : '';
  static String get supabaseAnonKey => dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] ?? '' : '';
  
  // [AI 스위치] 테스트 시에는 gemini, 상용화 시에는 openai로 변경하세요.
  static const AiProvider activeAiProvider = AiProvider.openai;

  static String get openAiApiKey => dotenv.isInitialized ? dotenv.env['OPENAI_API_KEY'] ?? '' : '';
  static String get geminiApiKey => dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] ?? '' : '';

  // 공식 웹사이트 정책 및 약관 URL (GitHub Pages)
  static const String privacyPolicyUrl = 'https://forevernewvie.github.io/present/privacy.html';
  static const String termsOfServiceUrl = 'https://forevernewvie.github.io/present/terms.html';
}
