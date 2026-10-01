import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:present_app/providers/settings_provider.dart';
import 'package:present_app/services/openai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Parent Title & Persona System Prompt Tests', () {
    test('buildSystemPrompt with 엄마 strictly enforces 엄마 and bans 아빠', () {
      final prompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: '엄마',
      );

      expect(prompt, contains('사용자는 어머니입니다'));
      expect(prompt, contains('반드시 "엄마"라는 호칭만 일관되게 사용하세요'));
      expect(prompt, contains('절대 "아빠"'));
    });

    test('buildSystemPrompt with 아빠 strictly enforces 아빠 and bans 엄마', () {
      final prompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: '아빠',
      );

      expect(prompt, contains('사용자는 아버지입니다'));
      expect(prompt, contains('반드시 "아빠"라는 호칭만 일관되게 사용하세요'));
      expect(prompt, contains('절대 "엄마"'));
    });

    test('buildSystemPrompt with none/empty omits specific title', () {
      final prompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: 'none',
      );

      expect(prompt, contains('호칭을 생략한 채 다정하고 상냥하게'));
    });

    test('buildSystemPrompt with neighbor or partner returns their prompts', () {
      final neighborPrompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.neighbor,
      );
      expect(neighborPrompt, contains('동년배 친구'));

      final partnerPrompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.partner,
      );
      expect(partnerPrompt, contains('라이프 파트너'));
    });
  });

  group('SettingsProvider State & Notifier Tests', () {
    test('SettingsNotifier updates state and OpenAiService static fields', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsProvider).parentTitle, '엄마');

      await notifier.setParentTitle('아빠');
      expect(container.read(settingsProvider).parentTitle, '아빠');
      expect(container.read(settingsProvider).isConfigured, isTrue);
      expect(OpenAiService.activeParentTitle, '아빠');

      await notifier.setPersona(PersonaType.partner);
      expect(container.read(settingsProvider).persona, PersonaType.partner);
      expect(OpenAiService.activePersona, PersonaType.partner);
    });

    test('SettingsState copyWith preserves or replaces properties', () {
      const state = SettingsState(isConfigured: true);
      final updated = state.copyWith(parentTitle: '아빠');
      expect(updated.isConfigured, isTrue);
      expect(updated.parentTitle, '아빠');

      final updatedAll = state.copyWith(isConfigured: false, persona: PersonaType.neighbor);
      expect(updatedAll.isConfigured, isFalse);
      expect(updatedAll.persona, PersonaType.neighbor);
    });

    test('SettingsNotifier loads saved preferences correctly', () async {
      SharedPreferences.setMockInitialValues({
        'setting_parent_title': '아빠',
        'setting_persona': 'neighbor',
        'setting_is_configured': true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger lazy build so _loadFromPrefs executes
      container.read(settingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(settingsProvider);
      expect(state.parentTitle, '아빠');
      expect(state.persona, PersonaType.neighbor);
      expect(state.isConfigured, isTrue);
    });
  });
}
