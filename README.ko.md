# Stock Manager Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.41%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![Release](https://img.shields.io/badge/Release-v1.0.0-111827)](https://github.com/suslmk-lee/stock-manager-mobile/releases/tag/v1.0.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Stock Manager Mobile은 주식 포트폴리오, 증권 계좌, 배당 내역을 KRW/USD 기준으로 관리하는 Flutter 모바일 앱입니다.

개인 투자 기록을 정확하게 관리하기 위해 계좌별 보유 종목, 배당 내역, 통화 환산, 월별 분석, 로고 기반 시각화를 제공합니다.

[Read this document in English](README.md)

## 주요 기능

- 총 배당금, 월별 인사이트, 최근 활동, 월별 배당 차트를 제공하는 홈 대시보드
- 계좌별 포트폴리오 필터, 보유 종목, 현재가 기반 평가금액, KRW/USD 전환
- 증권사 로고, 마스킹 계좌번호, 국내/해외 구분, 연결 종목을 보여주는 계좌 관리
- 계좌별 배당 내역, 배당 총합, 수정/삭제 스와이프 액션, 배당 분석
- 종목 및 증권사 로고 표시와 fallback 모노그램 배지
- Android 앱 아이콘 및 시작 화면 커스터마이징
- Bearer token 기반 REST API 연동

## 기술 스택

| 항목 | 기술 |
| --- | --- |
| Framework | Flutter / Dart |
| 상태 관리 | Riverpod |
| HTTP 클라이언트 | Dio |
| 차트 | fl_chart |
| 로컬 캐시 | shared_preferences |
| 플랫폼 | Android |
| 백엔드 | Fly.io에 배포된 REST API |

## 사전 준비

- Flutter SDK
- Android Studio 또는 Android SDK 도구
- Android 에뮬레이터 또는 실제 Android 기기
- 백엔드 API 키

## 환경 변수

프로젝트 루트에 `.env.json` 파일을 생성합니다.

```json
{
  "API_KEY": "your_api_key_here"
}
```

이 파일은 Git에 포함되지 않아야 합니다.

## 패키지 설치

```bash
flutter pub get
```

## Android 에뮬레이터 실행

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env.json
```

연결된 기기가 하나뿐이라면 디바이스 id를 생략할 수 있습니다.

```bash
flutter run --dart-define-from-file=.env.json
```

## APK 빌드

```bash
flutter build apk --dart-define-from-file=.env.json
```

APK 생성 위치는 다음과 같습니다.

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 프로젝트 구조

```text
lib/
├── core/
│   ├── constants.dart
│   └── theme/app_theme.dart
├── models/
│   ├── account.dart
│   ├── asset.dart
│   ├── dividend.dart
│   └── transaction.dart
├── providers/
│   ├── account_provider.dart
│   ├── asset_provider.dart
│   ├── dividend_provider.dart
│   └── price_provider.dart
├── screens/
│   ├── accounts/
│   ├── dividends/
│   ├── home/
│   └── portfolio/
├── services/
│   ├── api_service.dart
│   └── cache_service.dart
└── widgets/
```

## API 설정

| 항목 | 값 |
| --- | --- |
| 인증 방식 | `Authorization: Bearer {API_KEY}` |
| API 키 주입 | `.env.json`과 `--dart-define-from-file` 사용 |
| 현재가 갱신 | Provider 기반 캐시 및 주기적 갱신 |
| 오프라인 캐시 | SharedPreferences 기반 로컬 캐시 |

## 릴리즈

첫 APK는 GitHub Release에서 다운로드할 수 있습니다.

[Download v1.0.0](https://github.com/suslmk-lee/stock-manager-mobile/releases/tag/v1.0.0)

## 라이선스

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.
