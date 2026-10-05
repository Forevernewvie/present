import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/openai_service.dart';

class PersonaBottomSheet extends ConsumerWidget {
  final bool initialSetupOnly;

  const PersonaBottomSheet({
    super.key,
    this.initialSetupOnly = false,
  });

  static Future<void> show(BuildContext context, {bool initialSetupOnly = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonaBottomSheet(initialSetupOnly: initialSetupOnly),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 드래그 핸들 바
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 타이틀
            Text(
              initialSetupOnly ? '어떻게 불러드릴까요?' : '호칭 및 대화 상대 설정',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              initialSetupOnly
                  ? 'AI 자녀가 부모님을 부를 호칭을 선택해 주세요.'
                  : '원하시는 호칭과 대화 상대를 언제든 변경할 수 있습니다.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // [호칭 선택 섹션]
            if (!initialSetupOnly)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  '부모님 호칭',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: _TitleOptionCard(
                    icon: '👩',
                    label: '엄마',
                    isSelected: settings.parentTitle == '엄마',
                    onTap: () {
                      ref.read(settingsProvider.notifier).setParentTitle('엄마');
                      if (initialSetupOnly) Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _TitleOptionCard(
                    icon: '👨',
                    label: '아빠',
                    isSelected: settings.parentTitle == '아빠',
                    onTap: () {
                      ref.read(settingsProvider.notifier).setParentTitle('아빠');
                      if (initialSetupOnly) Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),

            // 전체 설정 모드일 때 페르소나 선택 노출
            if (!initialSetupOnly) ...[
              const SizedBox(height: 28),
              Text(
                '대화 상대 (페르소나)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PersonaOptionCard(
                      icon: '👧',
                      label: '다정한 자녀',
                      isSelected: settings.persona == PersonaType.child,
                      onTap: () {
                        ref.read(settingsProvider.notifier).setPersona(PersonaType.child);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PersonaOptionCard(
                      icon: '🤝',
                      label: '동년배 친구',
                      isSelected: settings.persona == PersonaType.neighbor,
                      onTap: () {
                        ref.read(settingsProvider.notifier).setPersona(PersonaType.neighbor);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PersonaOptionCard(
                      icon: '💡',
                      label: '스마트 파트너',
                      isSelected: settings.persona == PersonaType.partner,
                      onTap: () {
                        ref.read(settingsProvider.notifier).setPersona(PersonaType.partner);
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // 확인/닫기 버튼
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleOptionCard extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TitleOptionCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.08) : Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[200]!,
              width: isSelected ? 2.5 : 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? primaryColor : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaOptionCard extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonaOptionCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.08) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[200]!,
              width: isSelected ? 2.2 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
