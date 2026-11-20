import 'package:flutter_test/flutter_test.dart';
import 'package:stock_manager/services/kakao_probe.dart';

void main() {
  test('기록 파일: 한 줄에 JSON 하나, 최근 것이 앞, 깨진 줄은 건너뛴다', () {
    const raw =
        '{"kind":"broker","postTime":1,"title":"예시증권"}\n'
        'not json\n'
        '\n'
        '{"kind":"other","postTime":2,"lengths":{"text":5}}\n';
    final records = KakaoProbe.parseRecords(raw);
    expect(records, hasLength(2));
    expect(records.first['kind'], 'other');
    expect(records.last['title'], '예시증권');
  });

  test('빈 기록', () {
    expect(KakaoProbe.parseRecords(''), isEmpty);
  });
}
