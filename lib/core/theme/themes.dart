import 'package:flutter/material.dart';
import 'palette.dart';

// 앱 테마 목록. 데스크톱 frontend/src/appearance/themes.ts 의 THEMES 와 같은 값.
// 테마는 바탕(bg)·글자(fg)·강조(accent) 세 색만 정하고 나머지 단계는 AppPalette.build 가 섞어서 만든다.

@immutable
class AppThemeDef {
  final String id;
  final String name;
  final bool dark;
  final Color bg;
  final Color fg;
  final Color accent;

  /// 카드 바탕 (기본: bg 에서 fg 쪽으로 살짝)
  final Color? surface;

  /// 상태 색 덮어쓰기 (강조색이 주황·노랑 계열이면 amber 와 겹치지 않게 바꾼다)
  final Map<String, Color> status;

  /// 미리보기의 세 점 색 (기본: 강조색 + 흐린 색 둘)
  final List<Color>? swatches;

  const AppThemeDef({
    required this.id,
    required this.name,
    required this.bg,
    required this.fg,
    required this.accent,
    this.dark = true,
    this.surface,
    this.status = const {},
    this.swatches,
  });

  AppPalette get palette => _palettes[id] ??= AppPalette.build(
    bg: bg,
    fg: fg,
    accent: accent,
    dark: dark,
    surface: surface,
    status: status,
  );
}

final _palettes = <String, AppPalette>{};

// 퀀텀 · 천지인: 회사 로고 세 색 (빨강 · 초록 · 파랑)
const _triRed = Color(0xFFF24941);
const _triGreen = Color(0xFF79BA37);

const kDefaultThemeId = 'default';

const kThemes = <AppThemeDef>[
  AppThemeDef(
    id: 'default',
    name: '기본 (블랙 · 민트)',
    bg: Color(0xFF060607),
    fg: Color(0xFFFFFFFF),
    accent: Color(0xFF7DDFB0),
  ),
  AppThemeDef(
    id: 'quantum',
    name: '퀀텀 · 천지인',
    bg: Color(0xFF17191D),
    fg: Color(0xFFE7E9EC),
    accent: Color(0xFF5B8AD6),
    status: {'rose': _triRed, 'emerald': _triGreen},
    swatches: [_triRed, _triGreen, Color(0xFF5B8AD6)],
  ),
  AppThemeDef(
    id: 'graphite-blue',
    name: '그라파이트 · 파랑',
    bg: Color(0xFF111113),
    fg: Color(0xFFF4F4F5),
    accent: Color(0xFF6AA8FF),
  ),
  AppThemeDef(
    id: 'graphite-orange',
    name: '그라파이트 · 주황',
    bg: Color(0xFF111113),
    fg: Color(0xFFF4F4F5),
    accent: Color(0xFFF59E6B),
    status: {'amber': Color(0xFFA5B4FC), 'orange': Color(0xFFF472B6)},
  ),
  AppThemeDef(
    id: 'graphite-green',
    name: '그라파이트 · 초록',
    bg: Color(0xFF111113),
    fg: Color(0xFFF4F4F5),
    accent: Color(0xFF5CBF8A),
  ),
  AppThemeDef(
    id: 'monochrome',
    name: '모노크롬',
    bg: Color(0xFF0A0A0A),
    fg: Color(0xFFFAFAFA),
    accent: Color(0xFFD4D4D8),
  ),
  AppThemeDef(
    id: 'mauve',
    name: '모브 (회보라)',
    bg: Color(0xFF16131B),
    fg: Color(0xFFF3EEF7),
    accent: Color(0xFFC4A7E7),
  ),
  AppThemeDef(
    id: 'mocha',
    name: '모카 (갈색)',
    bg: Color(0xFF191411),
    fg: Color(0xFFF5EDE6),
    accent: Color(0xFFD9A46F),
    status: {'amber': Color(0xFF9FC4D9), 'orange': Color(0xFFE48FA8)},
  ),
  AppThemeDef(
    id: 'slate',
    name: '슬레이트 (청회색)',
    bg: Color(0xFF0E131A),
    fg: Color(0xFFE8EEF5),
    accent: Color(0xFF7FB0D9),
  ),
  AppThemeDef(
    id: 'dracula',
    name: 'Dracula',
    bg: Color(0xFF21222C),
    fg: Color(0xFFF8F8F2),
    accent: Color(0xFFBD93F9),
  ),
  AppThemeDef(
    id: 'nord',
    name: 'Nord',
    bg: Color(0xFF2E3440),
    fg: Color(0xFFECEFF4),
    accent: Color(0xFF88C0D0),
  ),
  AppThemeDef(
    id: 'tokyo-night',
    name: 'Tokyo Night',
    bg: Color(0xFF1A1B26),
    fg: Color(0xFFC0CAF5),
    accent: Color(0xFF7AA2F7),
  ),
  AppThemeDef(
    id: 'catppuccin-mocha',
    name: 'Catppuccin Mocha',
    bg: Color(0xFF1E1E2E),
    fg: Color(0xFFCDD6F4),
    accent: Color(0xFFCBA6F7),
  ),
  AppThemeDef(
    id: 'gruvbox',
    name: 'Gruvbox',
    bg: Color(0xFF1D2021),
    fg: Color(0xFFEBDBB2),
    accent: Color(0xFFFE8019),
    status: {
      'amber': Color(0xFFD3869B),
      'orange': Color(0xFF83A598),
      'emerald': Color(0xFFB8BB26),
      'rose': Color(0xFFFB4934),
    },
  ),
  AppThemeDef(
    id: 'rose-pine',
    name: 'Rosé Pine',
    bg: Color(0xFF191724),
    fg: Color(0xFFE0DEF4),
    accent: Color(0xFFEBBCBA),
  ),
  AppThemeDef(
    id: 'solarized-dark',
    name: 'Solarized Dark',
    bg: Color(0xFF002B36),
    fg: Color(0xFFEEE8D5),
    accent: Color(0xFF2AA198),
  ),
  AppThemeDef(
    id: 'light',
    name: '라이트 (민트)',
    dark: false,
    bg: Color(0xFFF4F5F7),
    fg: Color(0xFF111113),
    accent: Color(0xFF0F9F6E),
    surface: Color(0xFFFFFFFF),
  ),
  AppThemeDef(
    id: 'quantum-light',
    name: '퀀텀 · 천지인 (밝게)',
    dark: false,
    bg: Color(0xFFF3F5F8),
    fg: Color(0xFF1B1F26),
    accent: Color(0xFF4572BA),
    surface: Color(0xFFFFFFFF),
    status: {'rose': _triRed, 'emerald': _triGreen},
    swatches: [_triRed, _triGreen, Color(0xFF4572BA)],
  ),
  AppThemeDef(
    id: 'light-orange',
    name: '라이트 (주황)',
    dark: false,
    bg: Color(0xFFF6F6F4),
    fg: Color(0xFF1F2023),
    accent: Color(0xFFD0663A),
    surface: Color(0xFFFFFFFF),
    status: {'amber': Color(0xFFA5B4FC), 'orange': Color(0xFFF472B6)},
  ),
  AppThemeDef(
    id: 'solarized-light',
    name: 'Solarized Light',
    dark: false,
    bg: Color(0xFFFDF6E3),
    fg: Color(0xFF073642),
    accent: Color(0xFF268BD2),
    surface: Color(0xFFFFFBEF),
  ),
  AppThemeDef(
    id: 'catppuccin-latte',
    name: 'Catppuccin Latte',
    dark: false,
    bg: Color(0xFFEFF1F5),
    fg: Color(0xFF4C4F69),
    accent: Color(0xFF8839EF),
    surface: Color(0xFFFFFFFF),
  ),
];

AppThemeDef themeById(String? id) =>
    kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);
