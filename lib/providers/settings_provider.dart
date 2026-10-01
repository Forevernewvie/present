import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/openai_service.dart';

class SettingsState {
  final String parentTitle; // '엄마', '아빠', 'none'
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
      parentTitle: parentTitle ?? this.parentTitle,
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

      final finalTitle = savedTitle ?? '엄마';
      state = state.copyWith(
        parentTitle: finalTitle,
        persona: loadedPersona,
        isConfigured: isConfigured,
      );

      OpenAiService.activeParentTitle = finalTitle;
      OpenAiService.activePersona = loadedPersona;
    } catch (_) {
      // SharedPreferences 오류 시 기본값 유지
    }
  }

  Future<void> setParentTitle(String title) async {
    state = state.copyWith(
      parentTitle: title,
      isConfigured: true,
    );
    OpenAiService.activeParentTitle = title;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyParentTitle, title);
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
