# Stock Manager Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.41%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![Release](https://img.shields.io/badge/Release-v1.0.0-111827)](https://github.com/suslmk-lee/stock-manager-mobile/releases/tag/v1.0.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Stock Manager Mobile is a Flutter-based mobile app for tracking stock portfolios, brokerage accounts, and dividend income across KRW and USD.

It is designed for personal investment tracking with a focus on accurate financial totals, account-based organization, dividend analytics, and a polished mobile experience.

[한국어 문서 보기](README.ko.md)

## Features

- Home dashboard with total dividends, monthly insights, recent activity, and a monthly dividend chart
- Portfolio view with account filters, holdings, live price-based valuation, and KRW/USD conversion
- Account management with broker logos, masked account numbers, domestic/overseas labels, and linked holdings
- Dividend history with account filters, account-based summaries, edit/delete swipe actions, and analytics
- Stock and broker logo support with fallback monogram badges
- Android app icon and splash screen customization
- REST API integration with bearer-token authentication

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | Flutter / Dart |
| State management | Riverpod |
| HTTP client | Dio |
| Charts | fl_chart |
| Local cache | shared_preferences |
| Platform | Android |
| Backend | REST API deployed on Fly.io |

## Requirements

- Flutter SDK
- Android Studio or Android SDK tools
- A running Android emulator or Android device
- API key for the backend service

## Environment Variables

Create a `.env.json` file in the project root.

```json
{
  "API_KEY": "your_api_key_here"
}
```

The file is ignored by Git and should not be committed.

## Install Dependencies

```bash
flutter pub get
```

## Run on Android Emulator

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env.json
```

If only one device is connected, you can omit the device id.

```bash
flutter run --dart-define-from-file=.env.json
```

## Build APK

```bash
flutter build apk --dart-define-from-file=.env.json
```

The APK will be generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

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

## API Configuration

| Item | Value |
| --- | --- |
| Authentication | `Authorization: Bearer {API_KEY}` |
| API key source | `.env.json` via `--dart-define-from-file` |
| Price refresh behavior | Cached and periodically refreshed by providers |
| Offline cache | SharedPreferences-based local cache |

## Release

The first public APK is available from the GitHub release page:

[Download v1.0.0](https://github.com/suslmk-lee/stock-manager-mobile/releases/tag/v1.0.0)

## License

This project is licensed under the [MIT License](LICENSE).
