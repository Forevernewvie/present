#!/usr/bin/env bash
set -e

# ==============================================================================
# Present App - Strict Quality & Hardcore Testing Audit Harness (iOS + Android)
# Steps:
# 1. Strict Static Analysis (flutter analyze --fatal-infos --fatal-warnings)
# 2. Chaos & Adversarial Stress Tests (test/chaos_stress_test.dart)
# 3. Multi-Platform 2.0x Font Scaling & Multi-Device A11y Tests (test/accessibility_and_responsive_test.dart)
# 4. Android Hardware Form Factors, System Back Button & Manifest Tests (test/android_platform_and_devices_test.dart)
# 5. Randomized Full Test Suite with Coverage (flutter test --test-randomize-ordering-seed=random --coverage)
# 6. Strict Coverage Gating >= 98.50%
# ==============================================================================

echo "============================================================"
echo "🚀 [Present App] Strict Quality & Multi-Platform Test Harness"
echo "============================================================"

# Step 1: Strict Static Analysis
echo ""
echo "▶ [Step 1/6] 정적 분석 (Strict Static Analysis: fatal-infos & fatal-warnings)..."
flutter analyze --fatal-infos --fatal-warnings
echo "✅ [Step 1/6] 정적 분석 통과 (0 errors, 0 warnings, 0 infos)"

# Step 2: Chaos & Adversarial Stress Tests
echo ""
echo "▶ [Step 2/6] 카오스 & 스트레스 테스트 (Adversarial Fuzzing, Race Conditions, Cold Boot Restore)..."
flutter test test/chaos_stress_test.dart
echo "✅ [Step 2/6] 카오스 스트레스 테스트 100% 통과"

# Step 3: Multi-Platform 2.0x Font Scaling & Responsive A11y Tests
echo ""
echo "▶ [Step 3/6] iOS & 안드로이드 2.0배 폰트 및 해상도별 접근성 검증 (A11y & Zero Overflow)..."
flutter test test/accessibility_and_responsive_test.dart
echo "✅ [Step 3/6] 폰트 2.0배 및 iOS/안드로이드 기기별 오버플로우 0건 검증 완료"

# Step 4: Android Platform & Hardware Devices
echo ""
echo "▶ [Step 4/6] 안드로이드 삼성 갤럭시 전 기기군, 시스템 뒤로가기, OS 라이프사이클 및 매니페스트 검증..."
flutter test test/android_platform_and_devices_test.dart
echo "✅ [Step 4/6] 안드로이드 전용 하드웨어 및 시스템 동작 검증 100% 통과"

# Step 5: Randomized Full Test Suite with Coverage
echo ""
echo "▶ [Step 5/6] 전체 테스트 스위트 무작위 순서 실행 및 커버리지 측정..."
flutter test --test-randomize-ordering-seed=random --coverage
echo "✅ [Step 5/6] 전체 테스트 스위트 무작위 순서 100% 통과"

# Step 6: Strict Coverage Gating >= 98.50%
echo ""
echo "▶ [Step 6/6] 커버리지 98.50% 강제 게이팅 검사..."
python3 -c "
import sys

def verify_coverage(lcov_path, threshold=98.50):
    lines_found = 0
    lines_hit = 0
    with open(lcov_path, 'r') as f:
        for line in f:
            if line.startswith('DA:'):
                lines_found += 1
                parts = line.strip().split(',')
                if int(parts[1]) > 0:
                    lines_hit += 1
    if lines_found == 0:
        print('❌ [Error] lcov.info에 유효한 라인 데이터가 없습니다.')
        sys.exit(1)
    
    pct = (lines_hit / lines_found) * 100
    print(f'📊 최종 라인 커버리지: {pct:.2f}% (기준치: {threshold:.2f}%) [{lines_hit}/{lines_found} lines]')
    if pct < threshold:
        print(f'❌ [FAIL] 테스트 커버리지가 기준치 {threshold:.2f}%에 미달합니다!')
        sys.exit(1)
    else:
        print(f'🎉 [PASS] 커버리지 기준치 {threshold:.2f}%를 안정적으로 충족했습니다!')

verify_coverage('coverage/lcov.info', 98.50)
"

echo ""
echo "============================================================"
echo "🏆 [모든 검증 완료] iOS & 안드로이드 전체 초고강도 하네스 검증 통과 (100% GREEN)"
echo "============================================================"
