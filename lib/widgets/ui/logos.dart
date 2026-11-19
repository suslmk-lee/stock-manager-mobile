import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import 'app_icon.dart';

/// 종목 로고: 저장된 logo_url → 없으면 티커로 로고 서비스 → 실패하면 글자 두 개
class TickerLogo extends StatelessWidget {
  final String ticker;
  final String name;
  final String? logoUrl;
  final double size;

  const TickerLogo({
    super.key,
    required this.ticker,
    required this.name,
    this.logoUrl,
    this.size = 36,
  });

  String? get _url {
    final stored = logoUrl?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final t = ticker.trim().toUpperCase();
    if (t.isEmpty) return null;
    return 'https://financialmodelingprep.com/image-stock/${Uri.encodeComponent(t)}.png';
  }

  String get _monogram {
    String clean(String v) => v.replaceAll(RegExp(r'[^A-Za-z0-9가-힣]'), '');
    final source = clean(ticker).isNotEmpty ? clean(ticker) : clean(name);
    if (source.isEmpty) return '·';
    return String.fromCharCodes(source.runes.take(2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fallback = Center(
      child: Text(
        _monogram,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: p.zinc.s200,
        ),
      ),
    );
    final url = _url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: p.w(0.1)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.ink600, p.ink800],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: url == null
            ? fallback
            : Padding(
                padding: EdgeInsets.all(size * 0.17),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                ),
              ),
      ),
    );
  }
}

/// 증권사 로고 이미지 경로 (assets/brokers). 없으면 null
String? brokerLogoAsset(String broker) {
  final normalized = broker
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_·.]'), '')
      .replaceAll('증권', '')
      .replaceAll('투자', '')
      .replaceAll('금융', '');

  if (normalized.contains('kb') || normalized.contains('국민')) {
    return 'assets/brokers/kb.png';
  }
  if (normalized.contains('nh') ||
      normalized.contains('농협') ||
      normalized.contains('나무')) {
    return 'assets/brokers/NH.png';
  }
  if (normalized.contains('미래에셋') || normalized.contains('mirae')) {
    return 'assets/brokers/miraeasset.png';
  }
  if (normalized.contains('삼성') || normalized.contains('samsung')) {
    return 'assets/brokers/samsung.png';
  }
  if (normalized.contains('신한') || normalized.contains('shinhan')) {
    return 'assets/brokers/shinhan.png';
  }
  if (normalized.contains('토스') || normalized.contains('toss')) {
    return 'assets/brokers/toss.png';
  }
  if (normalized.contains('대신') || normalized.contains('daishin')) {
    return 'assets/brokers/daishin.png';
  }
  if (normalized.contains('카카오') || normalized.contains('kakao')) {
    return 'assets/brokers/kakao.png';
  }
  if (normalized.contains('한국') || normalized.contains('korea')) {
    return 'assets/brokers/korea.png';
  }
  if (normalized.contains('메리츠') || normalized.contains('meritz')) {
    return 'assets/brokers/meritz.png';
  }
  return null;
}

/// 증권사 로고 (데스크톱 BrokerLogo): 흰 바탕 상자, 로고가 없으면 지갑 아이콘
class BrokerLogo extends StatelessWidget {
  final String broker;
  final double width;
  final double height;

  const BrokerLogo({
    super.key,
    required this.broker,
    this.width = 56,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final asset = brokerLogoAsset(broker);
    final fallback = Center(
      child: AppIcon(AppGlyph.wallet, size: 18, color: p.zinc.s400),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.w(0.1)),
        color: asset == null ? p.w(0.035) : p.paper,
      ),
      child: asset == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => fallback,
                ),
              ),
            ),
    );
  }
}
