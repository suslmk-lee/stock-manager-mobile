import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/themes.dart';
import '../../core/theme/typography.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/ui/controls.dart';

/// 앱 테마 고르기. 누르면 바로 바뀌고(뒤 화면도 함께), 시트는 닫을 때까지 남는다.
Future<void> showThemeSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const _ThemeSheet(),
);

class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final selected = ref.watch(settingsProvider.select((s) => s.themeId));
    final dark = kThemes.where((t) => t.dark).toList();
    final light = kThemes.where((t) => !t.dark).toList();

    Widget row(AppThemeDef t) => ThemeOptionRow(
      theme: t,
      selected: t.id == selected,
      onTap: () => ref.read(settingsProvider.notifier).setTheme(t.id),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: p.w(0.1))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.w(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Text(
                  '앱 테마',
                  style: AppText.body(
                    p,
                    size: 16,
                    weight: FontWeight.w600,
                    color: p.white,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    GroupLabel('다크 · ${dark.length}'),
                    for (final t in dark) row(t),
                    const SizedBox(height: 10),
                    GroupLabel('라이트 · ${light.length}'),
                    for (final t in light) row(t),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 테마 한 줄: 미리보기 + 이름 (선택 = 강조색 테두리·바탕, 데스크톱 설정과 같다)
class ThemeOptionRow extends StatelessWidget {
  final AppThemeDef theme;
  final bool selected;
  final VoidCallback onTap;

  const ThemeOptionRow({
    super.key,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: r,
              color: selected
                  ? p.mint.s400.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: selected ? p.mint.s400 : p.w(0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                ThemePreview(theme: theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    theme.name,
                    style: AppText.body(p, color: p.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 20, color: p.mint.s300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 테마 미리보기 64×40: 위 막대(세 점) + 글자 두 줄 + 강조색 막대
class ThemePreview extends StatelessWidget {
  final AppThemeDef theme;
  final double width;
  final double height;

  const ThemePreview({
    super.key,
    required this.theme,
    this.width = 64,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bar = t.surface ?? mixColor(t.bg, t.fg, 0.05);
    final dim = mixColor(t.bg, t.fg, 0.35);
    final dots = t.swatches ?? [t.accent, dim, dim];
    Widget line(double w, double h, Color c) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(h),
      ),
    );
    final inner = width - 12;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mixColor(t.bg, t.fg, 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: height * 0.27,
            color: bar,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final c in dots) ...[
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 3),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(inner * 0.75, 3, t.fg.withValues(alpha: 0.9)),
                const SizedBox(height: 3),
                line(inner * 0.55, 3, t.fg.withValues(alpha: 0.45)),
                const SizedBox(height: 5),
                line(inner * 0.3, 4, t.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
