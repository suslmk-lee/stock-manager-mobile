import 'package:intl/intl.dart';

final _krw = NumberFormat('#,###');
final _usd = NumberFormat('#,##0.00');
final _qty = NumberFormat('#,##0.####');

/// 한국 거래소 종목(.KS 코스피, .KQ 코스닥)
bool isKrwTicker(String ticker) =>
    ticker.endsWith('.KS') || ticker.endsWith('.KQ');

String fmtKrw(num v) => '${v < 0 ? '−' : ''}₩${_krw.format(v.abs().round())}';
String fmtUsd(num v) => '${v < 0 ? '−' : ''}\$${_usd.format(v.abs())}';
String fmtMoney(num v, String currency) =>
    currency == 'KRW' ? fmtKrw(v) : fmtUsd(v);

/// +₩1,234 / −$5.00
String fmtSignedMoney(num v, String currency) =>
    '${v >= 0 ? '+' : '−'}${fmtMoney(v.abs(), currency)}';

/// +8.25% / −0.27%
String fmtSignedPct(num v, {int digits = 2}) =>
    '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(digits)}%';

String fmtQty(num v) => _qty.format(v);

/// 차트 라벨용 짧은 원화: 44.0만, 1.2억
String fmtKrwShort(num v) {
  final a = v.abs();
  final sign = v < 0 ? '−' : '';
  if (a >= 100000000) return '$sign${(a / 100000000).toStringAsFixed(1)}억';
  if (a >= 10000) return '$sign${(a / 10000).toStringAsFixed(1)}만';
  return '$sign${_krw.format(a.round())}';
}

/// 계좌번호 끝 4자리
String accountLast4(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp(r'\D'), '');
  return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
}
