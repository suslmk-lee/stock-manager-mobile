import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// 카톡 배당 알림 1단계 시험 — 안드로이드 KakaoNotificationListener 와 이어진다.
/// 카카오톡 알림이 어떤 모양으로 들어오는지 기기 안에만 기록한 것을 읽는다 (서버로 보내지 않는다).
class KakaoProbe {
  static const _ch = MethodChannel('stock_manager/kakao_probe');

  /// 안드로이드에서만 동작 (iOS 는 다른 앱 알림을 읽을 수 없다)
  static bool get supported => Platform.isAndroid;

  static Future<KakaoProbeStatus> status() async {
    final m = Map<String, dynamic>.from(
      await _ch.invokeMethod<Map>('status') ?? const {},
    );
    DateTime? at(String k) {
      final v = m[k];
      return v is int && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    }

    return KakaoProbeStatus(
      granted: m['granted'] == true,
      connected: m['connected'] == true,
      connectedAt: at('connectedAt'),
      kakaoSeen: (m['kakaoSeen'] as int?) ?? 0,
      brokerSaved: (m['brokerSaved'] as int?) ?? 0,
      lastKakaoAt: at('lastKakaoAt'),
    );
  }

  static Future<void> openSettings() => _ch.invokeMethod('openSettings');

  /// 알림창에 남아 있는 카톡 알림을 다시 읽는다. 새로 저장한 수 (연결 안 됨 = -1)
  static Future<int> scan() async => await _ch.invokeMethod<int>('scan') ?? -1;

  static Future<void> clear() => _ch.invokeMethod('clear');

  /// 기록 원문 (한 줄에 JSON 하나)
  static Future<String> rawRecords() async =>
      await _ch.invokeMethod<String>('records') ?? '';

  /// 기록 (최근 것이 앞)
  static Future<List<Map<String, dynamic>>> records() async =>
      parseRecords(await rawRecords());

  static List<Map<String, dynamic>> parseRecords(String raw) => [
    for (final line in const LineSplitter().convert(raw).reversed)
      if (line.trim().isNotEmpty)
        if (_tryDecode(line) case final Map<String, dynamic> m) m,
  ];

  static Object? _tryDecode(String line) {
    try {
      return jsonDecode(line);
    } catch (_) {
      return null;
    }
  }
}

class KakaoProbeStatus {
  /// '알림 읽기' 권한이 켜져 있다
  final bool granted;

  /// 알림 감지 서비스가 지금 붙어 있다
  final bool connected;
  final DateTime? connectedAt;

  /// 받은 카카오톡 알림 수 (내용 저장 여부와 관계없이)
  final int kakaoSeen;

  /// 내용까지 저장한 증권사 알림 수
  final int brokerSaved;
  final DateTime? lastKakaoAt;

  const KakaoProbeStatus({
    required this.granted,
    required this.connected,
    required this.connectedAt,
    required this.kakaoSeen,
    required this.brokerSaved,
    required this.lastKakaoAt,
  });
}
