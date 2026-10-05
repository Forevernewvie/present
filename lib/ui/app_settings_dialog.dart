import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'persona_bottom_sheet.dart';

class AppSettingsDialog extends ConsumerWidget {
  const AppSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AppSettingsDialog(),
    );
  }

  Future<void> _openPolicyUrl(BuildContext context, String url, String title, String fallbackContent) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched && context.mounted) {
        _showPolicyDialog(context, title, fallbackContent, webUrl: url);
      }
    } catch (_) {
      if (context.mounted) {
        _showPolicyDialog(context, title, fallbackContent, webUrl: url);
      }
    }
  }

  void _showPolicyDialog(BuildContext context, String title, String content, {String? webUrl}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            if (webUrl != null)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                tooltip: '웹페이지 열기',
                onPressed: () => launchUrl(Uri.parse(webUrl), mode: LaunchMode.inAppBrowserView),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                ),
                if (webUrl != null) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(webUrl), mode: LaunchMode.inAppBrowserView),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language, size: 18, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              webUrl,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2E7D32)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (webUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('웹사이트에서 보기'),
              onPressed: () {
                launchUrl(Uri.parse(webUrl), mode: LaunchMode.inAppBrowserView);
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '로그아웃하시겠습니까?\n기기 내 임시 대화 기록이 정리됩니다.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 설정 다이얼로그 닫기
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('회원 탈퇴 (계정 삭제)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          '정말로 계정을 삭제하고 탈퇴하시겠습니까?\n\n'
          '⚠️ 탈퇴 시 서버에 저장된 모든 대화 기록과 사용자 정보가 영구히 파기되며 복구할 수 없습니다.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop(); // 확인창 닫기
              Navigator.of(context).pop(); // 설정창 닫기
              await ref.read(authProvider.notifier).deleteAccount();
            },
            child: const Text('탈퇴 및 데이터 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '앱 설정 및 정보',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // 계정 정보 카드
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withAlpha(40),
                      child: Icon(Icons.person, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '손님 (게스트)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user != null ? '계정 ID: ${user.kakaoId ?? user.id.substring(0, 8)}' : '로그인되지 않음',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // AI 서비스 면책 안내 카드 (Store Guideline 대응)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Present AI의 답변은 정서적 말벗을 위한 것이며, 전문적인 의료·약학·법률 상담을 대체할 수 없습니다.',
                        style: TextStyle(fontSize: 13, color: Colors.brown.shade800, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 호칭 및 대화 상대 설정
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune, color: Colors.black87),
                title: const Text('호칭 및 대화 상대', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ref.watch(settingsProvider).parentTitle == '엄마'
                          ? '👩 엄마'
                          : (ref.watch(settingsProvider).parentTitle == '아빠' ? '👨 아빠' : '설정 안 함'),
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  PersonaBottomSheet.show(context);
                },
              ),
              const Divider(height: 1),

              // 정책 및 이용약관 메뉴
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined, color: Colors.black87),
                title: const Text('개인정보처리방침', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('웹 열기', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.primary),
                  ],
                ),
                onTap: () => _openPolicyUrl(
                  context,
                  Env.privacyPolicyUrl,
                  '개인정보처리방침',
                  'Present는 이용자의 개인정보 및 프라이버시를 최우선으로 보호합니다.\n\n'
                  '1. 음성 데이터 처리: 사용자가 마이크를 통해 발화한 오디오는 기기 내 STT 엔진을 통해 텍스트로 변환 즉시 파기되며, 음성 파일 원본은 서버에 저장되지 않습니다.\n\n'
                  '2. 대화 기록: 이용자가 직접 확인하는 달력 일기 제공을 위해 변환된 텍스트만 안전하게 암호화되어 보관됩니다.\n\n'
                  '3. 파기 권리: 이용자는 언제든지 로그아웃 또는 회원 탈퇴를 통해 모든 데이터를 영구 삭제할 수 있습니다.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, color: Colors.black87),
                title: const Text('서비스 이용약관', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('웹 열기', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.primary),
                  ],
                ),
                onTap: () => _openPolicyUrl(
                  context,
                  Env.termsOfServiceUrl,
                  '서비스 이용약관',
                  '제1조 (목적)\n본 약관은 Present(이하 "서비스")가 제공하는 시니어 AI 말벗 대화 서비스의 이용 조건 및 절차를 규정합니다.\n\n'
                  '제2조 (서비스의 내용)\n서비스는 인공지능 기반의 음성 대화 및 일상 기록 보관 기능을 제공합니다.\n\n'
                  '제3조 (이용자의 의무)\n이용자는 타인의 명예를 훼손하거나 불법적인 목적으로 서비스를 이용하여서는 아니 됩니다.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline, color: Colors.black87),
                title: const Text('앱 버전', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: const Text('1.0.0 (최신 버전)', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),

              const SizedBox(height: 16),

              // 계정 액션 (로그아웃 & 계정 삭제)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _confirmLogout(context, ref),
                      child: const Text('로그아웃', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _confirmDeleteAccount(context, ref),
                      child: const Text('회원 탈퇴', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
