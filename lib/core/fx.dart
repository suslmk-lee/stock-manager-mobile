import 'package:intl/intl.dart';

// 여러 통화 → 원화 (데스크톱 frontend/src/utils/fx.ts 와 같은 규칙).
// 달러는 앱 환율(/exchange-rate/usd-krw)을 쓰고, 엔화·유로 등은 {통화}KRW=X 시세로 바꾼다.
// 예전에는 원화가 아니면 모두 달러로 봐서 도쿄 상장 엔화 종목이 크게 틀렸다.

/// 통화 이름 정리: 대문자로, 펜스(GBp) 같은 1/100 단위는 그대로. 비어 있으면 ''
String normalizeCurrency(String? currency) {
  final c = (currency ?? '').trim();
  if (c.isEmpty) return '';
  if (c == 'GBp' || c == 'GBX' || c == 'ILA' || c == 'ZAc') return c;
  return c.toUpperCase();
}

// 거래소 꼬리표로 짐작한 종목 통화 (현재가를 못 받았을 때). 서버 currencyFor 와 같은 규칙
const _suffixCurrency = [
  ('.KS', 'KRW'),
  ('.KQ', 'KRW'),
  ('.T', 'JPY'),
  ('.HK', 'HKD'),
  ('.SS', 'CNY'),
  ('.SZ', 'CNY'),
  ('.TWO', 'TWD'),
  ('.TW', 'TWD'),
  ('.L', 'GBp'),
  ('.TO', 'CAD'),
  ('.AX', 'AUD'),
  ('.SI', 'SGD'),
  ('.DE', 'EUR'),
  ('.PA', 'EUR'),
  ('.VI', 'EUR'),
];

String currencyOfTicker(String ticker) {
  final t = ticker.trim().toUpperCase();
  if (t.startsWith('FUND:')) return 'KRW';
  for (final (suffix, currency) in _suffixCurrency) {
    if (t.endsWith(suffix.toUpperCase())) return currency;
  }
  return 'USD';
}

/// 통화 1단위의 원화 값을 주는 시세 티커와 배수 (펜스는 파운드의 1/100)
(String symbol, double multiplier) fxSymbolOf(String currency) =>
    switch (currency) {
      'GBp' || 'GBX' => ('GBPKRW=X', 0.01),
      'ILA' => ('ILSKRW=X', 0.01),
      'ZAc' => ('ZARKRW=X', 0.01),
      _ => ('${currency}KRW=X', 1),
    };

/// 통화별 원화 환율. 원화 1, 달러는 앱 환율. 모르는 통화는 null (원화로 잘못 읽지 않게)
class FxRates {
  final double usdKrw;
  final Map<String, double> others;

  const FxRates({required this.usdKrw, this.others = const {}});

  double? krwPerUnit(String currency) {
    final c = normalizeCurrency(currency);
    if (c == 'KRW') return 1;
    if (c == 'USD') return usdKrw > 0 ? usdKrw : null;
    final r = others[c];
    return r != null && r > 0 ? r : null;
  }

  double? toKrw(double value, String currency) {
    final r = krwPerUnit(currency);
    return r == null ? null : value * r;
  }
}

const _symbols = {
  'KRW': '₩',
  'USD': '\$',
  'JPY': '¥',
  'CNY': 'CN¥',
  'HKD': 'HK\$',
  'TWD': 'NT\$',
  'EUR': '€',
  'GBP': '£',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'SGD': 'S\$',
};

/// 통화 기호 (₩ · $ · ¥ · € …), 모르는 통화는 코드 그대로
String currencySymbol(String? currency) {
  final c = normalizeCurrency(currency);
  if (c == 'GBp') return 'p';
  return _symbols[c] ?? c;
}

// 소수점 없이 쓰는 통화
const _noDecimals = {'KRW', 'JPY', 'TWD'};
final _int = NumberFormat('#,##0');
final _dec = NumberFormat('#,##0.00');

/// 금액 표시: ₩1,234 · $12.34 · ¥3,000 · €99.50 · 123p (마이너스는 −)
String formatCurrency(num v, String? currency) {
  final c = normalizeCurrency(currency).isEmpty
      ? 'USD'
      : normalizeCurrency(currency);
  final abs = v.abs();
  final whole = _noDecimals.contains(c);
  final body = c == 'GBp'
      ? '${_dec.format(abs)}p'
      : '${_symbols[c] ?? '$c '}${whole ? _int.format(abs.round()) : _dec.format(abs)}';
  // 반올림해서 0 이 되는 음수에는 − 를 붙이지 않는다
  final shownZero = whole ? abs < 0.5 : abs < 0.005;
  return v < 0 && !shownZero ? '−$body' : body;
}
