import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';

/// 앱을 켤 때 로고 시작 화면 (CI). 뒤에서는 첫 화면이 미리 만들어지며 데이터를 받는다.
///
/// 네이티브 스플래시(검정 #060607 바탕 + 가운데 브랜드 마크 150dp)와 같은 모습에서 시작해
/// 마크가 조금 작아지며 위로 올라가고, 워드마크가 나타난 뒤 전체가 사라진다.
/// 누르면 바로 넘어간다. 앱이 처음 만들어질 때 한 번만 보인다.
class IntroGate extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const IntroGate({super.key, required this.enabled, required this.child});

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1700);

  /// 이 시점부터 사라지기 시작 (0~1)
  static const _fadeFrom = 0.78;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  late bool _done = !widget.enabled;

  @override
  void initState() {
    super.initState();
    if (!_done) {
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    }
  }

  void _skip() {
    if (_c.value < _fadeFrom) _c.forward(from: _fadeFrom);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (!_done)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skip,
              child: _IntroView(animation: _c, fadeFrom: _fadeFrom),
            ),
          ),
      ],
    );
  }
}

class _IntroView extends AnimatedWidget {
  final double fadeFrom;

  const _IntroView({
    required Animation<double> animation,
    required this.fadeFrom,
  }) : super(listenable: animation);

  // 네이티브 스플래시와 맞춘 값 (tool/render_icons.sh: 1152px 중 600px = 288dp 중 150dp)
  static const _bg = Color(0xFF060607);
  static const _startSize = 150.0;
  static const _endSize = 104.0;
  static const _rise = 46.0;

  double _seg(
    double t,
    double a,
    double b, [
    Curve curve = Curves.easeOutCubic,
  ]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    // 시작 화면은 테마와 관계없이 기본(블랙 · 민트) 색 — 네이티브 스플래시와 이어지게
    final p = AppPalette.defaultDark;
    final t = (listenable as Animation<double>).value;
    final move = _seg(t, 0.06, 0.42);
    final word = _seg(t, 0.24, 0.52);
    final tag = _seg(t, 0.34, 0.62);
    final out = _seg(t, fadeFrom, 1, Curves.easeInCubic);

    final size = _startSize + (_endSize - _startSize) * move;
    return Opacity(
      opacity: 1 - out,
      // Material: 글자 기본 스타일 (없으면 디버그용 노란 밑줄이 그려진다)
      child: Material(
        color: _bg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 마크 뒤 은은한 강조색 빛
            Transform.translate(
              offset: Offset(0, -_rise * move),
              child: Opacity(
                opacity: 0.5 * move,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        p.mint.s400.withValues(alpha: 0.22),
                        p.mint.s400.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -_rise * move),
              child: Transform.scale(
                scale: 1 + 0.015 * math.sin(math.pi * move),
                child: Image.asset(
                  'assets/branding/intro_mark.png',
                  width: size,
                  height: size,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, _endSize / 2 - _rise + 40 + 10 * (1 - word)),
              child: Opacity(
                opacity: word,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Stock ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: p.white,
                        ),
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
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: kSans,
                    fontSize: 28,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, _endSize / 2 - _rise + 76 + 8 * (1 - tag)),
              child: Opacity(
                opacity: tag,
                child: Text(
                  'PORTFOLIO · DIVIDEND',
                  textScaler: TextScaler.noScaling,
                  style: AppText.label(
                    p,
                    size: 10.5,
                    color: p.zinc.s500,
                  ).copyWith(letterSpacing: 2.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
