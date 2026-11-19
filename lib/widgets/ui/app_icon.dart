import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/palette.dart';

// 데스크톱 appIcons.tsx 의 "어긋난 두 색" 아이콘.
// 24 격자의 선(글자색) 위에 색 면을 오른쪽 아래로 1.2 어긋나게 겹친다 (면 = 강조색 70%).
// 메뉴 · 화면 제목 · 카드 머리에 쓰고, 버튼 안 작은 기능 아이콘(닫기·추가 등)은 Material 아이콘을 쓴다.

enum AppGlyph {
  home,
  wallet,
  trend,
  coin,
  bars,
  calendar,
  receipt,
  podium,
  layers,
  history,
}

// [선, 면] — 이 파일의 상수만 넣는다 (밖에서 받은 값을 SVG 에 넣지 않는다)
const Map<AppGlyph, List<String>> _paths = {
  AppGlyph.home: [
    '<path d="M4 10.5 12 4l8 6.5V19a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 19z"/><path d="M9.5 20.5v-6h5v6"/>',
    '<rect x="9.5" y="14.5" width="5" height="6" rx="1"/>',
  ],
  AppGlyph.wallet: [
    '<path d="M18.5 7.5V6a1.5 1.5 0 0 0-1.5-1.5H5.5a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-13"/><path d="M20.5 11.5h-3a2 2 0 0 0 0 4h3"/>',
    '<rect x="14" y="10.5" width="6.5" height="6" rx="2.5"/>',
  ],
  AppGlyph.trend: [
    '<path d="M3.5 17.5l5-5 3.5 3.5 8-8M15 8h5v5"/>',
    '<path d="M4 20l4.5-5 3.5 3.5 7.5-7.5V20z"/>',
  ],
  AppGlyph.coin: [
    '<circle cx="12" cy="12" r="8.5"/><path d="M14.6 9.3c-.4-.9-1.4-1.4-2.6-1.4-1.5 0-2.6.8-2.6 2 0 2.7 5.3 1.4 5.3 4.2 0 1.2-1.1 2-2.7 2-1.3 0-2.3-.6-2.7-1.5M12 6.3v1.6M12 16.1v1.6"/>',
    '<path d="M12 3.5A8.5 8.5 0 0 1 20.5 12H12z"/>',
  ],
  AppGlyph.bars: [
    '<path d="M3.5 20.5h17"/><rect x="5" y="12" width="3.5" height="8.5" rx="1"/><rect x="10.25" y="7.5" width="3.5" height="13" rx="1"/><rect x="15.5" y="4" width="3.5" height="16.5" rx="1"/>',
    '<rect x="10.25" y="7.5" width="3.5" height="13" rx="1"/>',
  ],
  AppGlyph.calendar: [
    '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 9.5h17M8 3v4M16 3v4M7.5 13h2M11 13h2M14.5 13h2M7.5 16.5h2M11 16.5h2"/>',
    '<rect x="14" y="15" width="3.5" height="3" rx="1"/>',
  ],
  AppGlyph.receipt: [
    '<path d="M6 3.5h12v17l-2-1.3-2 1.3-2-1.3-2 1.3-2-1.3-2 1.3z"/><path d="M9 8h6M9 11.5h6M9 15h3.5"/>',
    '<rect x="8.5" y="6.8" width="7" height="2.6" rx="1"/>',
  ],
  AppGlyph.podium: [
    '<path d="M9 9.5h6v11H9zM3.5 13.5H9v7H3.5zM15 15.5h5.5v5H15z"/><path d="M12 3.2l.9 1.8 2 .3-1.45 1.4.35 2-1.8-.95-1.8.95.35-2L9.1 5.3l2-.3z"/>',
    '<path d="M9 9.5h6v11H9z"/>',
  ],
  AppGlyph.layers: [
    '<path d="M12 4l8.5 4.5L12 13 3.5 8.5z"/><path d="M3.5 12.5 12 17l8.5-4.5M3.5 16.5 12 21l8.5-4.5"/>',
    '<path d="M12 4l8.5 4.5L12 13 3.5 8.5z"/>',
  ],
  AppGlyph.history: [
    '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3L4.5 9"/><path d="M4.5 4.5V9H9"/><path d="M12 8v4.5l3 1.8"/>',
    '<path d="M12 4.5a7.5 7.5 0 0 1 7.5 7.5H12z"/>',
  ],
};

String _hex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

class AppIcon extends StatelessWidget {
  final AppGlyph glyph;
  final double size;

  /// 선 색 (기본: 주변 글자색 zinc-200)
  final Color? color;

  /// 면 색 (기본: 테마 강조색)
  final Color? fill;

  const AppIcon(this.glyph, {super.key, this.size = 20, this.color, this.fill});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final line = color ?? p.zinc.s200;
    final face = fill ?? p.mint.s400;
    final [l, f] = _paths[glyph]!;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<g fill="${_hex(face)}" fill-opacity="0.7" transform="translate(1.2 1.2)">$f</g>'
        '<g fill="none" stroke="${_hex(line)}" stroke-opacity="${line.a.toStringAsFixed(3)}" '
        'stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">$l</g>'
        '</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
