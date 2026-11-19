import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

// 데스크톱 card-styles.css 의 'glass'(리퀴드 글라스) 스타일.
//  .surface        카드: 반경 24, 흰 8% 테두리, 흰 4.5→1.2% 세로 그라데이션, 위쪽 광택, 깊은 아래 그림자
//  .surface-inset  카드 안 패널: 반경 16, 흰 7% 테두리, 흰 3.5→1.5%
//  .hero-grain     대표 카드: 반경 32, 사선 광원 + 그레인

/// 테두리를 그리되 위쪽만 조금 더 밝게 (CSS 의 `inset 0 1px 0 white/6%` 광택 대신)
class _RimPainter extends CustomPainter {
  final BorderRadius radius;
  final Color top;
  final Color base;

  _RimPainter({required this.radius, required this.top, required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final topStop = (28 / math.max(size.height, 1)).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, base, base],
        stops: [0, topStop, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.top != top || old.base != base || old.radius != radius;
}

/// 긴 목록용 카드 바탕 (DecoratedSliver 에 쓴다). GlassCard 와 같은 면·테두리·그림자
BoxDecoration glassCardDecoration(AppPalette p, {double radius = 24}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: p.w(0.08)),
      color: Color.alphaBlend(p.w(0.025), p.surface),
      boxShadow: [
        BoxShadow(
          color: p.shadow.withValues(alpha: 0.9 * p.shadowK),
          offset: const Offset(0, 24),
          blurRadius: 48,
          spreadRadius: -24,
        ),
      ],
    );

/// 최상위 카드 (.surface). onTap 이 있으면 눌림 효과를 준다.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final bool clip;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
    this.onTap,
    this.clip = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(radius);
    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: r, child: content),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: p.surface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(p.w(0.045), p.surface),
            Color.alphaBlend(p.w(0.012), p.surface),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: 0.9 * p.shadowK),
            offset: const Offset(0, 24),
            blurRadius: 48,
            spreadRadius: -24,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _RimPainter(
          radius: r,
          top: p.w(0.14),
          base: p.w(0.08),
        ),
        child: clip ? ClipRRect(borderRadius: r, child: content) : content,
      ),
    );
  }
}

/// 카드 안 패널 (.surface-inset)
class InsetPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const InsetPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: r, child: content),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.w(0.035), p.w(0.015)],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _RimPainter(
          radius: r,
          top: p.w(0.11),
          base: p.w(0.07),
        ),
        child: content,
      ),
    );
  }
}

/// 대표 카드 (.hero-grain): 왼쪽 위 광원 + 사선 빛 + 그레인 노이즈
class HeroCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  static ui.Image? _grain;
  static Future<ui.Image>? _loading;

  @override
  void initState() {
    super.initState();
    if (_grain == null) {
      _loading ??= _makeGrain();
      _loading!.then((img) {
        _grain = img;
        if (mounted) setState(() {});
      });
    }
  }

  // 160×160 회색 노이즈 (CSS 의 feTurbulence 그레인 대신). 한 번만 만든다.
  static Future<ui.Image> _makeGrain() {
    const size = 160;
    final rnd = math.Random(7);
    final bytes = Uint8List(size * size * 4);
    for (var i = 0; i < size * size; i++) {
      final v = rnd.nextInt(256);
      bytes[i * 4] = v;
      bytes[i * 4 + 1] = v;
      bytes[i * 4 + 2] = v;
      bytes[i * 4 + 3] = 255;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      size,
      size,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    const r = BorderRadius.all(Radius.circular(32));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: 0.95 * p.shadowK),
            offset: const Offset(0, 30),
            blurRadius: 60,
            spreadRadius: -30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: CustomPaint(
          painter: _HeroPainter(p, _grain),
          foregroundPainter: _RimPainter(
            radius: r,
            top: p.w(0.17),
            base: p.w(0.09),
          ),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final AppPalette p;
  final ui.Image? grain;

  _HeroPainter(this.p, this.grain);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = p.ink950);

    // linear-gradient(115deg, white .16 0%, white .07 28%, transparent 46%)
    final a = 115 * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final half = (size.width * dir.dx.abs() + size.height * dir.dy.abs()) / 2;
    final c = rect.center;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          c - dir * half,
          c + dir * half,
          [p.w(0.16), p.w(0.07), p.w(0)],
          [0, 0.28, 0.46],
        ),
    );

    // radial-gradient(60% 120% at 8% 0%, white .22 0%, white .06 35%, transparent 65%)
    canvas.save();
    canvas.translate(size.width * 0.08, 0);
    canvas.scale(size.width * 0.6, size.height * 1.2);
    canvas.drawRect(
      const Rect.fromLTRB(-2, -2, 2, 2),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [p.w(0.22), p.w(0.06), p.w(0)],
          [0, 0.35, 0.65],
        ),
    );
    canvas.restore();

    // 그레인 (opacity .22, overlay)
    final g = grain;
    if (g != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.overlay
          ..color = Colors.white.withValues(alpha: 0.22)
          ..shader = ImageShader(
            g,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.p != p || old.grain != grain;
}
