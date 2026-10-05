import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    test('buildSystemPrompt with any non-아빠 value defaults to 엄마', () {
      final prompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: 'none',
      );

      expect(prompt, contains('사용자는 어머니입니다'));
      expect(prompt, contains('반드시 "엄마"라는 호칭만 일관되게 사용하세요'));
      expect(prompt, contains('대화 도중 호칭이 변경되었더라도 이전 대화 내용에 구애받지 말고 이번 답변부터 즉시 "엄마"라고 불러야 합니다'));
    });

    test('buildSystemPrompt with 아빠 contains mid-call transition rule', () {
      final prompt = OpenAiService.buildSystemPrompt(
        persona: PersonaType.child,
        parentTitle: '아빠',
      );

      expect(prompt, contains('대화 도중 호칭이 변경되었더라도 이전 대화 내용에 구애받지 말고 이번 답변부터 즉시 "아빠"라고 불러야 합니다'));
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
    test('SettingsNotifier normalizes unknown titles to 엄마', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      await notifier.setParentTitle('none');
      expect(container.read(settingsProvider).parentTitle, '엄마');
      expect(OpenAiService.activeParentTitle, '엄마');

      await notifier.setParentTitle('삼촌');
      expect(container.read(settingsProvider).parentTitle, '엄마');
    });

    test('OpenAiService getAiReply sends dynamic parentTitle and persona in messages', () async {
      String? capturedSystemPrompt;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        capturedSystemPrompt = messages.first['content'] as String;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '아빠, 오늘 산책 다녀오셨어요?'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiService(client: mockClient, apiKey: 'sk-test');
      final reply = await service.getAiReply(
        userMessage: '안녕',
        persona: 'child',
        parentTitle: '아빠',
      );

      expect(reply, contains('아빠'));
      expect(capturedSystemPrompt, contains('사용자는 아버지입니다'));
      expect(capturedSystemPrompt, contains('대화 도중 호칭이 변경되었더라도'));
    });
  });
}
