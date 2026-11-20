import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../services/kakao_probe.dart';
import '../../widgets/ui/app_icon.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../../widgets/ui/surfaces.dart';

/// 카톡 배당 알림 1단계 시험 화면: 권한 · 감지 상태 · 기록된 알림 원문
class KakaoProbeScreen extends StatefulWidget {
  const KakaoProbeScreen({super.key});

  @override
  State<KakaoProbeScreen> createState() => _KakaoProbeScreenState();
}

class _KakaoProbeScreenState extends State<KakaoProbeScreen>
    with WidgetsBindingObserver {
  KakaoProbeStatus? _status;
  List<Map<String, dynamic>> _records = const [];
  String _raw = '';

  static final _time = DateFormat('MM/dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정에서 권한을 켜고 돌아오면 바로 다시 읽는다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await KakaoProbe.status();
    final raw = await KakaoProbe.rawRecords();
    if (!mounted) return;
    setState(() {
      _status = status;
      _raw = raw;
      _records = KakaoProbe.parseRecords(raw);
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _scan() async {
    final n = await KakaoProbe.scan();
    await _refresh();
    _toast(n < 0 ? '감지 서비스가 아직 연결되지 않았습니다' : '알림창에서 새로 $n개를 기록했습니다');
  }

  Future<void> _copy() async {
    if (_raw.trim().isEmpty) return _toast('복사할 기록이 없습니다');
    await Clipboard.setData(ClipboardData(text: _raw));
    _toast('기록 ${_records.length}개를 복사했습니다');
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 지우기'),
        content: const Text('기록한 알림과 숫자를 모두 지웁니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await KakaoProbe.clear();
    await _refresh();
  }

  String _fmt(Object? ms) => ms is int && ms > 0
      ? _time.format(DateTime.fromMillisecondsSinceEpoch(ms))
      : '-';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.ink950,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: Row(
          children: [
            IconCircleButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '뒤로',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('카톡 배당 알림 시험')),
          ],
        ),
        actions: [
          IconCircleButton(
            icon: Icons.copy_rounded,
            tooltip: '기록 복사',
            onPressed: _copy,
          ),
          IconCircleButton(
            icon: Icons.delete_outline_rounded,
            tooltip: '기록 지우기',
            onPressed: _clear,
          ),
        ],
      ),
      body: AmbientBackground(
        child: Builder(
          builder: (context) => RefreshIndicator(
            onRefresh: _refresh,
            edgeOffset: MediaQuery.paddingOf(context).top,
            child: ListView(
              padding: listPadding(context, top: 16),
              children: [
                _statusCard(p),
                const SizedBox(height: 14),
                _guideCard(p),
                const SizedBox(height: 18),
                GroupLabel('기록 · ${_records.length} (최근 것이 위)'),
                if (_records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '아직 기록이 없습니다',
                      textAlign: TextAlign.center,
                      style: AppText.body(p, color: p.zinc.s500),
                    ),
                  ),
                for (final r in _records) ...[
                  r['kind'] == 'broker' ? _brokerTile(p, r) : _otherTile(p, r),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(AppPalette p, String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: AppText.body(p, color: p.zinc.s300)),
        ),
        value,
      ],
    ),
  );

  Widget _value(AppPalette p, String text) =>
      Text(text, style: AppText.num(p, size: 13, color: p.white));

  Widget _statusCard(AppPalette p) {
    final s = _status;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardHeader(glyph: AppGlyph.receipt, title: '상태'),
          const SizedBox(height: 6),
          _row(
            p,
            '알림 읽기 권한',
            s == null
                ? _value(p, '…')
                : s.granted
                ? const StatusBadge(label: '허용됨', tone: BadgeTone.mint)
                : PrimaryPillButton(
                    label: '권한 열기',
                    onPressed: KakaoProbe.openSettings,
                  ),
          ),
          const RowDivider(),
          _row(
            p,
            '감지 서비스',
            s == null
                ? _value(p, '…')
                : StatusBadge(
                    label: s.connected ? '연결됨' : '연결 안 됨',
                    tone: s.connected ? BadgeTone.mint : BadgeTone.amber,
                  ),
          ),
          const RowDivider(),
          _row(
            p,
            '받은 카톡 알림',
            _value(
              p,
              s == null
                  ? '…'
                  : '${s.kakaoSeen}개 · 마지막 ${_fmt(s.lastKakaoAt?.millisecondsSinceEpoch)}',
            ),
          ),
          const RowDivider(),
          _row(
            p,
            '저장한 증권사 알림',
            _value(p, s == null ? '…' : '${s.brokerSaved}개'),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '증권사 채널 알림만 내용을 저장하고, 다른 카톡 알림은 글자 수만 남깁니다. 서버로 보내지 않습니다.',
                  style: AppText.body(p, size: 12, color: p.zinc.s500),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _scan, child: const Text('알림창 다시 읽기')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideCard(AppPalette p) {
    Widget step(String n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(n, style: AppText.num(p, size: 13, color: p.mint.s300)),
          ),
          Expanded(
            child: Text(
              text,
              style: AppText.body(p, size: 13, color: p.zinc.s300),
            ),
          ),
        ],
      ),
    );
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(glyph: AppGlyph.sparkle, title: '시험 방법'),
          const SizedBox(height: 10),
          step(
            '1',
            "'권한 열기'에서 'Stock Manager 배당 알림'을 켭니다. "
                "'제한된 설정' 안내가 뜨면 앱 정보 → 오른쪽 위 ⋮ → '제한된 설정 허용' 뒤 다시 켭니다.",
          ),
          step(
            '2',
            '카카오톡에서 증권사 채널 알림과 메시지 미리보기가 켜져 있어야 합니다. 채팅방을 보고 있을 때 온 메시지는 알림이 뜨지 않습니다.',
          ),
          step(
            '3',
            '증권사 알림톡이 오면 여기에 기록됩니다 (배당이 아닌 알림도 모양 확인에 도움이 됩니다). 기록이 쌓이면 오른쪽 위 복사 버튼으로 복사해 보내 주세요.',
          ),
        ],
      ),
    );
  }

  String _template(Object? t) =>
      t is String ? t.split(r'$').last.split('.').last : '-';

  Widget _field(AppPalette p, String name, Object? value) {
    if (value == null || (value is String && value.isEmpty)) {
      return const SizedBox.shrink();
    }
    final text = value is List ? value.join('\n') : value.toString();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · ${text.length}자',
            style: AppText.label(p, color: p.zinc.s500),
          ),
          const SizedBox(height: 4),
          SelectableText(
            text,
            style: AppText.body(p, size: 13, color: p.zinc.s100),
          ),
        ],
      ),
    );
  }

  Widget _brokerTile(AppPalette p, Map<String, dynamic> r) {
    final messages = (r['messages'] as List?) ?? const [];
    final keys = (r['keys'] as Map?) ?? const {};
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r['title'] ?? r['conversationTitle'] ?? '(제목 없음)'}',
                  style: AppText.body(
                    p,
                    size: 15,
                    weight: FontWeight.w600,
                    color: p.white,
                  ),
                ),
              ),
              Text(
                _fmt(r['postTime']),
                style: AppText.label(p, color: p.zinc.s400),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              MonoChip(label: _template(r['template'])),
              MonoChip(label: r['source'] == 'active' ? '알림창' : '새 알림'),
              if (r['groupSummary'] == true) const MonoChip(label: '묶음 요약'),
              if (r['isGroupConversation'] == true)
                const MonoChip(label: '단체방'),
            ],
          ),
          _field(p, 'text', r['text']),
          _field(p, 'bigText', r['bigText']),
          _field(p, 'textLines', r['textLines']),
          if (messages.isNotEmpty)
            _field(p, 'messages', [
              for (final m in messages.whereType<Map>())
                '${m['sender'] ?? '?'}: ${m['text'] ?? ''}',
            ]),
          _field(p, 'subText', r['subText']),
          _field(p, 'conversationTitle', r['conversationTitle']),
          const SizedBox(height: 10),
          Text(
            keys.entries.map((e) => '${e.key}=${e.value}').join('  '),
            style: AppText.label(p, size: 10, color: p.zinc.s600),
          ),
        ],
      ),
    );
  }

  Widget _otherTile(AppPalette p, Map<String, dynamic> r) {
    final len = (r['lengths'] as Map?) ?? const {};
    return InsetPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다른 카톡 알림 · 내용 저장 안 함',
                  style: AppText.body(p, size: 13, color: p.zinc.s300),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_template(r['template'])} · 제목 ${len['title']}자 · 본문 ${len['text']}자 · 긴 본문 ${len['bigText']}자 · 메시지 ${len['messages']}개',
                  style: AppText.label(p, color: p.zinc.s500),
                ),
              ],
            ),
          ),
          Text(
            _fmt(r['postTime']),
            style: AppText.label(p, color: p.zinc.s500),
          ),
        ],
      ),
    );
  }
}
