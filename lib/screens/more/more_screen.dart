import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/fx.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../providers/dividend_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/cache_service.dart';
import '../../services/kakao_probe.dart';
import '../../widgets/ui/app_icon.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../../widgets/ui/surfaces.dart';
import 'kakao_probe_screen.dart';
import 'theme_sheet.dart';

final appVersionProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// 저장된 캐시 항목 수·크기 (지우면 다시 읽는다)
final cacheStatsProvider = FutureProvider.autoDispose<({int count, int bytes})>(
  (ref) => ref.watch(cacheServiceProvider).stats(),
);

/// 더보기 탭: 모양(테마·글자 크기·시작 화면) · 환율 · 데이터 · 앱 정보.
/// 데스크톱 모바일 화면의 '더보기'(모양 설정·환율·버전)와 같은 자리.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(title: Text('더보기')),
      body: Builder(
        builder: (context) => ListView(
          padding: listPadding(context, top: 16),
          children: [
            const _AppearanceCard(),
            const SizedBox(height: 14),
            const _FxCard(),
            const SizedBox(height: 14),
            const _DataCard(),
            const SizedBox(height: 14),
            if (KakaoProbe.supported) ...[
              const _LabCard(),
              const SizedBox(height: 14),
            ],
            const _AboutCard(),
          ],
        ),
      ),
    );
  }
}

/// 카드 안 한 줄: 왼쪽 라벨(+설명) / 오른쪽 컨트롤
class _SettingRow extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.label,
    this.hint,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(p, color: p.white)),
                if (hint != null) ...[
                  const SizedBox(height: 3),
                  Text(hint!, style: AppText.label(p, color: p.zinc.s500)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ?trailing,
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: p.zinc.s500),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: row,
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 6),
      child: Column(
        children: [
          const CardHeader(glyph: AppGlyph.palette, title: '모양'),
          const SizedBox(height: 6),
          _SettingRow(
            label: '앱 테마',
            hint: settings.theme.name,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ThemePreview(theme: settings.theme, width: 48, height: 30),
            ),
            onTap: () => showThemeSheet(context),
          ),
          const RowDivider(),
          _SettingRow(
            label: '글자 크기',
            hint: '${settings.fontSize.px.toStringAsFixed(0)}px 기준',
            trailing: GlassSegmented<FontSizeOption>(
              items: [for (final f in FontSizeOption.values) (f, f.label)],
              selected: settings.fontSize,
              onChanged: notifier.setFontSize,
            ),
          ),
          const RowDivider(),
          _SettingRow(
            label: '시작 화면',
            hint: '앱을 켤 때 로고 화면 보여 주기',
            trailing: Switch(
              value: settings.showIntro,
              onChanged: notifier.setShowIntro,
              activeTrackColor: p.mint.s400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FxCard extends ConsumerWidget {
  const _FxCard();

  static final _rate = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final fx = ref.watch(fxRatesProvider);
    final usdLoaded = ref.watch(exchangeRateProvider).valueOrNull != null;
    final others = fx.others.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    Widget rateRow(String pair, double perUnit, {String? note}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(pair, style: AppText.label(p, size: 12, color: p.zinc.s400)),
          if (note != null) ...[
            const SizedBox(width: 6),
            Text(note, style: AppText.label(p, color: p.amber.s300)),
          ],
          const Spacer(),
          Text(
            '₩${_rate.format(perUnit)}',
            style: AppText.num(
              p,
              size: 15,
              weight: FontWeight.w500,
              color: p.white,
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(glyph: AppGlyph.coin, title: '환율'),
          const SizedBox(height: 4),
          Text(
            '해외 종목을 원화로 바꿀 때 쓰는 값 (1단위 기준)',
            style: AppText.body(p, size: 12, color: p.zinc.s500),
          ),
          const SizedBox(height: 6),
          rateRow('USD/KRW', fx.usdKrw, note: usdLoaded ? null : '기본값'),
          for (final e in others) ...[
            const RowDivider(),
            // 펜스(GBp) 같은 1/100 단위는 원래 통화(GBP) 1단위로 보여 준다
            () {
              final (symbol, mult) = fxSymbolOf(e.key);
              final base = symbol.replaceAll('KRW=X', '');
              return rateRow('$base/KRW', e.value / mult);
            }(),
          ],
        ],
      ),
    );
  }
}

class _DataCard extends ConsumerWidget {
  const _DataCard();

  String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 지우기'),
        content: const Text(
          '서버에 연결되지 않을 때 보여 주려고 저장해 둔 데이터를 지웁니다.\n'
          '서버의 계좌·종목·배당 기록은 그대로입니다.',
        ),
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
    if (ok != true || !context.mounted) return;
    final n = await ref.read(cacheServiceProvider).clearAll();
    ref.invalidate(cacheStatsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('캐시 $n개를 지웠습니다')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cacheStatsProvider).valueOrNull;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 6),
      child: Column(
        children: [
          const CardHeader(glyph: AppGlyph.box, title: '데이터'),
          const SizedBox(height: 6),
          _SettingRow(
            label: '오프라인 캐시',
            hint: stats == null
                ? '…'
                : stats.count == 0
                ? '저장된 캐시 없음'
                : '${stats.count}개 · ${_size(stats.bytes)}',
            trailing: TextButton(
              onPressed: stats == null || stats.count == 0
                  ? null
                  : () => _clear(context, ref),
              child: const Text('지우기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 실험 중인 기능 (안드로이드만)
class _LabCard extends StatelessWidget {
  const _LabCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 6),
      child: Column(
        children: [
          const CardHeader(glyph: AppGlyph.sparkle, title: '실험'),
          const SizedBox(height: 6),
          _SettingRow(
            label: '카톡 배당 알림 시험',
            hint: '1단계 · 알림 모양 기록',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const KakaoProbeScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final info = ref.watch(appVersionProvider).valueOrNull;
    final version = info == null
        ? '…'
        : '${info.version} (${info.buildNumber})';
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 6),
      child: Column(
        children: [
          const CardHeader(glyph: AppGlyph.info, title: '앱 정보'),
          const SizedBox(height: 6),
          _SettingRow(
            label: '버전',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                version,
                style: AppText.num(p, size: 13, color: p.zinc.s300),
              ),
            ),
          ),
          const RowDivider(),
          _SettingRow(
            label: '오픈소스 라이선스',
            hint: '글꼴 · 패키지',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Stock Manager',
              applicationVersion: info?.version,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/branding/brand_mark.png',
                  width: 56,
                  height: 56,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
