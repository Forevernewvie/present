import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/openai_service.dart';

class SettingsState {
  final String parentTitle; // '엄마', '아빠'
  final PersonaType persona;
  final bool isConfigured;

  const SettingsState({
    this.parentTitle = '엄마',
    this.persona = PersonaType.child,
    this.isConfigured = false,
  });

  SettingsState copyWith({
    String? parentTitle,
    PersonaType? persona,
    bool? isConfigured,
  }) {
    return SettingsState(
      parentTitle: parentTitle != null
          ? (parentTitle == '아빠' ? '아빠' : '엄마')
          : this.parentTitle,
      persona: persona ?? this.persona,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _keyParentTitle = 'setting_parent_title';
  static const String _keyPersona = 'setting_persona';
  static const String _keyConfigured = 'setting_is_configured';

  @override
  SettingsState build() {
    _loadFromPrefs();
    return const SettingsState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTitle = prefs.getString(_keyParentTitle);
      final savedPersonaStr = prefs.getString(_keyPersona);
      final isConfigured = prefs.getBool(_keyConfigured) ?? (savedTitle != null);

      PersonaType loadedPersona = PersonaType.child;
      if (savedPersonaStr != null) {
        for (final p in PersonaType.values) {
          if (p.name == savedPersonaStr) {
            loadedPersona = p;
            break;
          }
        }
      }

      // 만약 SharedPreferences를 비동기 로딩하는 도중 사용자가 이미 설정을 변경했다면 덮어쓰지 않습니다.
      final bool hasUserOverridden = state.isConfigured;
      final finalTitle = hasUserOverridden
          ? state.parentTitle
          : ((savedTitle == '아빠') ? '아빠' : '엄마');
      final finalPersona = hasUserOverridden ? state.persona : loadedPersona;

      state = state.copyWith(
        parentTitle: finalTitle,
        persona: finalPersona,
        isConfigured: isConfigured || hasUserOverridden,
      );

      OpenAiService.activeParentTitle = finalTitle;
      OpenAiService.activePersona = finalPersona;
    } catch (_) {
      // SharedPreferences 오류 시 기본값 유지
    }
  }

  Future<void> setParentTitle(String title) async {
    final normalizedTitle = (title == '아빠') ? '아빠' : '엄마';
    state = state.copyWith(
      parentTitle: normalizedTitle,
      isConfigured: true,
    );
    OpenAiService.activeParentTitle = normalizedTitle;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyParentTitle, normalizedTitle);
      await prefs.setBool(_keyConfigured, true);
    } catch (_) {}
  }

  Future<void> setPersona(PersonaType persona) async {
    state = state.copyWith(
      persona: persona,
      isConfigured: true,
    );
    OpenAiService.activePersona = persona;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPersona, persona.name);
      await prefs.setBool(_keyConfigured, true);
    } catch (_) {}
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
