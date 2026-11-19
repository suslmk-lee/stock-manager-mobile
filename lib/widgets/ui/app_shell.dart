import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import 'app_icon.dart';

// 데스크톱 DESIGN_TEMPLATE §6.3 상단 바 · §8 모바일 하단 탭.
// 둘 다 .app-header 바탕(ink-950 / 70%) + 흐림 24px + 흰 7~8% 경계선.

const double kTopBarHeight = 56;
const double kSubTabsHeight = 46;

/// 상단 바: 제목(왼쪽) + 도구(오른쪽), 필요하면 아래에 알약 줄.
/// Scaffold(extendBodyBehindAppBar: true) 와 함께 써서 본문이 바 뒤로 흐리게 지나가게 한다.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget> actions;
  final Widget? bottom;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kTopBarHeight + (bottom != null ? kSubTabsHeight : 0));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.ink950.withValues(alpha: 0.72),
            border: Border(bottom: BorderSide(color: p.w(0.07))),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: kTopBarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DefaultTextStyle(
                            style: AppText.pageTitle(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: title,
                          ),
                        ),
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          actions[i],
                        ],
                      ],
                    ),
                  ),
                ),
                if (bottom != null)
                  SizedBox(
                    height: kSubTabsHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: bottom,
                      ),
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

/// 브랜드 워드마크: 마크 + "Stock Manager" (두 굵기)
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/branding/brand_mark.png', width: 30, height: 30),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Stock ',
                style: TextStyle(fontWeight: FontWeight.w600, color: p.white),
              ),
              TextSpan(
                text: 'Manager',
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  color: p.zinc.s400,
                ),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: kSans,
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class AppTab {
  final String label;
  final AppGlyph glyph;

  const AppTab(this.label, this.glyph);
}

/// 하단 탭: 아이콘 22px 위 · 글자 11px 아래, 선택 = 강조색 300
class AppTabBar extends StatelessWidget {
  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  const AppTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.ink950.withValues(alpha: 0.72),
            border: Border(top: BorderSide(color: p.w(0.08))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: InkResponse(
                      onTap: () => onChanged(i),
                      radius: 40,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 9, bottom: 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              tabs[i].glyph,
                              size: 22,
                              color: i == index ? p.mint.s300 : p.zinc.s500,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tabs[i].label,
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 11,
                                fontWeight: i == index
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: i == index ? p.mint.s300 : p.zinc.s500,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// 바탕 + 위쪽 앰비언트 광원 (radial white 6%, 높이 420)
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ColoredBox(
      color: p.ink950,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.0,
                    colors: [p.w(0.06), p.w(0)],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// 상단 바·하단 탭에 가리지 않게 목록에 줄 안쪽 여백
EdgeInsets listPadding(
  BuildContext context, {
  double top = 12,
  double bottom = 24,
  double h = 16,
}) {
  final mq = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(h, mq.top + top, h, mq.bottom + bottom);
}
