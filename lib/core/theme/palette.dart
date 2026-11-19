import 'package:flutter/material.dart';

// 데스크톱 앱(stock-manager frontend/src/appearance/themes.ts)의 테마 규칙을 그대로 옮긴 색 체계.
// 테마는 바탕(bg)·글자(fg)·강조(accent) 세 색만 정하고 나머지 단계는 섞어서 만든다.
// 지금은 기본 테마(블랙 · 민트) 하나만 쓰지만, 다른 테마도 세 색만 넣으면 같은 규칙으로 만들어진다.

/// a 에서 b 쪽으로 t 만큼 섞기 (t=0 → a, t=1 → b). 데스크톱 mix() 와 같다.
Color mixColor(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// 한 색의 50~950 단계. 낮은 단계는 글자색 쪽, 높은 단계는 바탕색 쪽으로 섞는다.
@immutable
class Shades {
  final Color s50, s100, s200, s300, s400, s500, s600, s700, s800, s900, s950;

  const Shades({
    required this.s50,
    required this.s100,
    required this.s200,
    required this.s300,
    required this.s400,
    required this.s500,
    required this.s600,
    required this.s700,
    required this.s800,
    required this.s900,
    required this.s950,
  });

  factory Shades.from(Color base, Color fg, Color bg) => Shades(
    s50: mixColor(base, fg, 0.85),
    s100: mixColor(base, fg, 0.72),
    s200: mixColor(base, fg, 0.52),
    s300: mixColor(base, fg, 0.28),
    s400: base,
    s500: mixColor(base, bg, 0.12),
    s600: mixColor(base, bg, 0.25),
    s700: mixColor(base, bg, 0.4),
    s800: mixColor(base, bg, 0.55),
    s900: mixColor(base, bg, 0.7),
    s950: mixColor(base, bg, 0.82),
  );
}

/// 화면에서 쓰는 색 토큰. Theme 확장으로 넣고 `context.pal` 로 읽는다.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final bool isDark;

  /// 최대 대비 글자·얇은 면·테두리 (라이트 테마에서는 어두운 글자색)
  final Color white;

  /// 모달 배경막 (다크=검정)
  final Color black;

  /// 항상 흰색 (증권사 로고 바탕)
  final Color paper;
  final Color shadow;

  /// 그림자 세기 계수 (다크 1, 라이트 0.18)
  final double shadowK;

  /// 바탕 → 카드 → 테두리 순으로 밝아지는 무채색 면
  final Color ink950, ink900, ink850, ink800, ink700, ink600, ink500;

  /// 카드 바탕
  final Color surface;

  /// 글자·아이콘 중립색 (50 이 가장 밝음)
  final Shades zinc;

  /// 테마 강조색 (이름은 mint 지만 테마마다 색이 다르다). 긍정·상승·선택
  final Shades mint;
  final Shades amber;

  /// 위험·하락·매도·오류
  final Shades rose;
  final Shades emerald;
  final Shades sky;
  final Shades orange;

  const AppPalette({
    required this.isDark,
    required this.white,
    required this.black,
    required this.paper,
    required this.shadow,
    required this.shadowK,
    required this.ink950,
    required this.ink900,
    required this.ink850,
    required this.ink800,
    required this.ink700,
    required this.ink600,
    required this.ink500,
    required this.surface,
    required this.zinc,
    required this.mint,
    required this.amber,
    required this.rose,
    required this.emerald,
    required this.sky,
    required this.orange,
  });

  /// 데스크톱 buildThemeVars() 와 같은 규칙으로 세 색에서 모든 단계를 만든다.
  factory AppPalette.build({
    required Color bg,
    required Color fg,
    required Color accent,
    bool dark = true,
    Color? surface,
    Map<String, Color> status = const {},
  }) {
    Color ink(double t) => mixColor(bg, fg, t);
    Shades statusShades(String name, Color fallback) {
      final raw = status[name] ?? fallback;
      final base = dark ? raw : mixColor(raw, fg, 0.38);
      return Shades.from(base, fg, bg);
    }

    return AppPalette(
      isDark: dark,
      white: fg,
      black: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      paper: const Color(0xFFFFFFFF),
      shadow: dark ? const Color(0xFF000000) : mixColor(fg, bg, 0.3),
      shadowK: dark ? 1 : 0.18,
      ink950: ink(0),
      ink900: ink(0.016),
      ink850: ink(0.035),
      ink800: ink(0.055),
      ink700: ink(0.085),
      ink600: ink(0.13),
      ink500: ink(0.2),
      surface: surface ?? ink(0.03),
      zinc: Shades(
        s50: ink(0.97),
        s100: ink(0.92),
        s200: ink(0.84),
        s300: ink(0.72),
        s400: ink(0.6),
        s500: ink(0.45),
        s600: ink(0.33),
        s700: ink(0.22),
        s800: ink(0.14),
        s900: ink(0.08),
        s950: ink(0.04),
      ),
      mint: Shades.from(accent, fg, bg),
      amber: statusShades('amber', const Color(0xFFFBBF24)),
      rose: statusShades('rose', const Color(0xFFFB7185)),
      emerald: statusShades('emerald', const Color(0xFF34D399)),
      sky: statusShades('sky', const Color(0xFF38BDF8)),
      orange: statusShades('orange', const Color(0xFFFB923C)),
    );
  }

  /// 기본 테마 (블랙 · 민트)
  static final AppPalette defaultDark = AppPalette.build(
    bg: const Color(0xFF060607),
    fg: const Color(0xFFFFFFFF),
    accent: const Color(0xFF7DDFB0),
  );

  /// white 를 투명도와 함께 (데스크톱의 `white/[0.08]` 같은 얇은 면·테두리)
  Color w(double alpha) => white.withValues(alpha: alpha);

  /// 오르면 강조색, 내리면 rose (글자용 300 단계)
  Color trend(num value) => value >= 0 ? mint.s300 : rose.s300;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppPaletteContext on BuildContext {
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.defaultDark;
}
