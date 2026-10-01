# 🌿 마음선물 (Present)

> **"시니어를 위한 따뜻한 AI 말벗 대화 서비스"**  
> 복잡한 스마트폰 조작 없이, 자녀와 통화하듯 편안한 음성으로 대화하고 하루 일상을 달력에 따뜻하게 기록하는 효도 서비스입니다.

[![CI](https://github.com/Forevernewvie/present/actions/workflows/ci.yml/badge.svg)](https://github.com/Forevernewvie/present/actions/workflows/ci.yml)
[![Pages](https://github.com/Forevernewvie/present/actions/workflows/deploy_pages.yml/badge.svg)](https://forevernewvie.github.io/present/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 📱 주요 핵심 기능

1. **🎙️ 원터치 음성 대화 (Voice-First)**
   - 타이핑이 어려운 50~70대 시니어 부모님을 위해 화면 중앙 마이크 버튼 터치 한 번으로 음성 대화 시작.
   - 크고 선명한 활자(24pt+)와 다정한 음성(TTS) 응답.
2. **👵 다정한 3종 맞춤형 페르소나**
   - 듬직한 자녀(아들/딸), 다정한 손주, 친근한 동네 친구 페르소나 설정 지원.
3. **📅 달력으로 모아보는 추억 일기**
   - 매일 나눈 따뜻한 대화가 날짜별 달력에 자동으로 일기 형태로 보관되어 언제든 열람 가능.
4. **🔒 철저한 프라이버시 & 음성 원본 즉시 폐기**
   - 마이크 음성은 기기 내에서 텍스트로 변환 즉시 메모리에서 완전 폐기되며, 오디오 원본 파일은 서버에 저장되지 않습니다.
   - Row-Level Security(RLS) 및 멀티 유저 격리 적용.

---

## 🛠️ 기술 스택 (Tech Stack)

* **Frontend**: Flutter 3.x, Dart, Riverpod (Clean Architecture & Multi-User Isolation)
* **Design & UX**: Pretendard Typography, High-Contrast Senior Accessibility (A11y 2.0x Scaled)
* **Auth & DB**: Supabase Auth (Kakao OAuth 매핑), PostgreSQL (RLS 격리)
* **AI Engine**: Google Gemini API via Secure Supabase Edge Function
* **CI/CD**: GitHub Actions (Lint, Test, Auto-Pages Deploy, Semantic Release)

---

## 📜 공식 정책 및 약관

* 🌐 [마음선물 공식 정책 허브](https://forevernewvie.github.io/present/)
* 🔒 [개인정보처리방침 (Privacy Policy)](https://forevernewvie.github.io/present/privacy.html)
* 📜 [서비스 이용약관 (Terms of Service)](https://forevernewvie.github.io/present/terms.html)

---

## 🚀 시작하기 (Getting Started)

### 1. 환경 설정 (.env)
```bash
cp .env.example .env.dev
# Supabase URL 및 API 키 입력
```

### 2. 패키지 설치 및 테스트 실행
```bash
flutter pub get
flutter test
```

### 3. 앱 실행
```bash
flutter run
```

---

## 📦 배포 전략 (Modern Git & CI/CD Strategy)

* **Trunk-Based Delivery**: `main` 브랜치는 상시 배포 가능한 클린 빌드 상태 유지.
* **Continuous Integration**: PR 및 `main` 푸시 시 `ci.yml`을 통해 `flutter analyze`와 `flutter test` 자동 검증.
* **GitHub Pages**: `main` 푸시 시 `deploy_pages.yml`을 통해 `docs/` 정적 사이트 자동 배포.
* **Release Automation**: `v1.0.0`과 같은 Git Tag 푸시 시 `release.yml`이 AAB 및 APK 빌드 후 GitHub Release에 에셋 자동 업로드.
