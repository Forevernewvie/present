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

  void _showReportAiContentDialog(BuildContext context) {
    String selectedReason = '부적절하거나 불쾌한 표현';
    final reasons = [
      '부적절하거나 불쾌한 표현',
      '부정확하거나 위험한 정보 (의료·약학·법률 등)',
      '문맥에 맞지 않거나 어색한 답변',
      '기타 안전 및 품질 문제',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.redAccent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '부적절한 AI 답변 신고',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 말벗의 답변 중 불편하거나 부적절한 내용이 있었다면 사유를 선택해 주세요. 운영팀이 검토하여 즉시 개선하겠습니다.',
                style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedReason = val);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI 답변 신고가 정상적으로 접수되었습니다. 안전한 대화를 위해 신속히 검토하겠습니다.'),
                  ),
                );
              },
              child: const Text('신고 접수', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
                      ref.watch(settingsProvider).parentTitle == '아빠' ? '👨 아빠' : '👩 엄마',
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
                  'Present(com.presentcare.app)는 이용자의 개인정보 및 프라이버시를 최우선으로 보호합니다.\n\n'
                  '1. 수집 항목: 카카오 로그인 고유 식별자(ID) 및 닉네임, 음성에서 변환된 텍스트(STT 결과) 및 대화 일시.\n\n'
                  '2. 음성 데이터 원본 미보관: 사용자가 마이크(RECORD_AUDIO)를 통해 발화한 오디오는 기기 내 STT 엔진을 통해 텍스트로 변환된 즉시 폐기되며, 음성 파일 원본은 서버로 전송되거나 저장되지 않습니다.\n\n'
                  '3. 앱 접근 권한: 마이크(RECORD_AUDIO, 음성 대화 필수), 블루투스/오디오(BLUETOOTH_CONNECT·MODIFY_AUDIO_SETTINGS, 오디오 기기 연결 선택, 위치 추적 미사용), 인터넷(INTERNET, 암호화 통신 필수).\n\n'
                  '4. 제3자 처리 위탁: Supabase Inc.(DB/인증), OpenAI L.L.C. 및 Google LLC(AI 응답 생성), (주)카카오(소셜 로그인).\n\n'
                  '5. 즉시 파기 권리(회원 탈퇴): 앱 내 [회원 탈퇴] 또는 고객지원(cjb11055@naver.com)을 통해 언제든지 계정과 모든 대화 데이터를 유예 기간 없이 영구 삭제할 수 있습니다.',
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
                  '제1조 (목적)\n본 약관은 Present(com.presentcare.app)가 제공하는 시니어 AI 말벗 대화 서비스의 이용 조건 및 절차를 규정합니다.\n\n'
                  '제2조 (의료·전문 상담 면책)\n서비스는 정서적 위로를 위한 AI 말벗 서비스이며, 의료·약학·법률 자문을 대체하지 않습니다.\n\n'
                  '제3조 (AI 생성 콘텐츠 신고)\n부적절한 AI 응답은 앱 내 [부적절한 AI 답변 신고] 메뉴를 통해 즉시 신고할 수 있습니다.\n\n'
                  '제4조 (계약 해지 및 문의)\n언제든지 앱 내 [회원 탈퇴] 또는 cjb11055@naver.com을 통해 계정 및 데이터를 영구 삭제할 수 있습니다.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined, color: Colors.black87),
                title: const Text('부적절한 AI 답변 신고', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showReportAiContentDialog(context),
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
