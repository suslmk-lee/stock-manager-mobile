import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import 'app_icon.dart';

// 데스크톱 index.css 의 컴포넌트 클래스 (.glass-pill, .btn-primary, .btn-icon, .badge, .chip, .icon-tile …)

/// 알약 그룹 세그먼트 (.glass-pill + .pill-item)
class GlassSegmented<T> extends StatelessWidget {
  final List<(T value, String label)> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const GlassSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: p.w(0.035),
        border: Border.all(color: p.w(0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: value == selected ? p.w(0.09) : Colors.transparent,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    fontWeight: value == selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: value == selected ? p.white : p.zinc.s400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 묶음 안 페이지 알약 줄 (DESIGN_TEMPLATE §8). 선택 = 강조색 테두리·바탕
class SubPageTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SubPageTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: i == index
                    ? p.mint.s400.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: i == index
                      ? p.mint.s400.withValues(alpha: 0.4)
                      : p.w(0.1),
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  fontWeight: i == index ? FontWeight.w500 : FontWeight.w400,
                  color: i == index ? p.white : p.zinc.s400,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 작은 주 버튼 (.btn-primary): 흰색 세로 그라데이션 + 어두운 글자, 알약형.
/// 라이트 테마에서는 검정 버튼이 무거워 보여 강조색 면 + 흰 글자 (데스크톱과 같다)
class PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const PrimaryPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = p.isDark ? p.ink950 : p.paper;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.isDark
              ? [p.white, p.zinc.s200]
              : [p.mint.s400, p.mint.s500],
        ),
        boxShadow: [
          BoxShadow(
            color: p.isDark ? p.w(0.35) : p.mint.s400.withValues(alpha: 0.7),
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 7, 13, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 아이콘 전용 동그란 버튼 (.btn-icon) 32×32
class IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  const IconCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final button = Material(
      color: p.w(0.03),
      shape: CircleBorder(side: BorderSide(color: p.w(0.08))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: p.zinc.s400),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

enum BadgeTone { mint, rose, amber, neutral }

/// 상태 배지 (.badge): 테두리 / 바탕 / 글자 색을 의미에 맞춰
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (border, bg, fg) = switch (tone) {
      BadgeTone.mint => (
        p.mint.s400.withValues(alpha: 0.3),
        p.mint.s400.withValues(alpha: 0.1),
        p.mint.s300,
      ),
      BadgeTone.rose => (
        p.rose.s400.withValues(alpha: 0.3),
        p.rose.s500.withValues(alpha: 0.1),
        p.rose.s200,
      ),
      BadgeTone.amber => (
        p.amber.s400.withValues(alpha: 0.3),
        p.amber.s400.withValues(alpha: 0.1),
        p.amber.s200,
      ),
      BadgeTone.neutral => (p.w(0.1), p.w(0.05), p.zinc.s300),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: AppText.num(p, size: 11, weight: FontWeight.w500, color: fg),
          ),
        ],
      ),
    );
  }
}

/// 고정폭 칩 (.chip)
class MonoChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const MonoChip({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: p.w(0.045),
          border: Border.all(color: p.w(0.07)),
        ),
        child: Text(label, style: AppText.label(p, color: p.zinc.s300)),
      ),
    );
  }
}

/// 아이콘 타일 (.icon-tile-mint): 40×40, 아래쪽 강조색 글로우
class IconTile extends StatelessWidget {
  final AppGlyph glyph;
  final double size;

  const IconTile(this.glyph, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(size * 0.3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: p.w(0.1)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.ink600, p.ink800],
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: 0.9 * p.shadowK),
            offset: const Offset(0, 6),
            blurRadius: 16,
            spreadRadius: -8,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: RadialGradient(
            center: const Alignment(0, 1.4),
            radius: 0.9,
            colors: [
              p.mint.s400.withValues(alpha: 0.3),
              p.mint.s400.withValues(alpha: 0),
            ],
          ),
        ),
        child: Center(child: AppIcon(glyph, size: size * 0.5)),
      ),
    );
  }
}

/// 카드 머리: 두 색 아이콘 + 제목 + 오른쪽 동작
class CardHeader extends StatelessWidget {
  final AppGlyph? glyph;
  final String title;
  final Widget? trailing;
  final bool statLabel;

  const CardHeader({
    super.key,
    this.glyph,
    required this.title,
    this.trailing,
    this.statLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        if (glyph != null) ...[
          AppIcon(glyph!, size: 20),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: statLabel ? AppText.statLabel(p) : AppText.sectionTitle(p),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// "전체 보기 ›" 같은 작은 링크
class TextLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const TextLink({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.body(p, size: 12.5, color: p.zinc.s400)),
            Icon(Icons.chevron_right_rounded, size: 16, color: p.zinc.s500),
          ],
        ),
      ),
    );
  }
}

/// 묶음 이름 (.nav-group-label) — "국내 · 18"
class GroupLabel extends StatelessWidget {
  final String text;

  const GroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
    child: Text(text, style: AppText.groupLabel(context.pal)),
  );
}

/// 카드 안 목록 줄 사이 구분선 (흰 4%)
class RowDivider extends StatelessWidget {
  final double indent;

  const RowDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.only(left: indent),
    color: context.pal.w(0.045),
  );
}
