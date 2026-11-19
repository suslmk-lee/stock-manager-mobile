import 'package:flutter/material.dart';
import 'palette.dart';

// 데스크톱 DESIGN_TEMPLATE §4 글자 크기와 역할.
// 본문은 Pretendard, 숫자·보조 라벨은 고정폭 JetBrains Mono (한글은 Pretendard 로 대체).
const kSans = 'Pretendard';
const kMono = 'JetBrainsMono';
const _monoFallback = [kSans];
const _tabular = [FontFeature.tabularFigures()];

class AppText {
  AppText._();

  /// 고정폭 보조 라벨 (.label-mono): 11px, 자간 넓게, zinc-500
  static TextStyle label(AppPalette p, {double size = 11, Color? color}) =>
      TextStyle(
        fontFamily: kMono,
        fontFamilyFallback: _monoFallback,
        fontSize: size,
        height: 1.35,
        letterSpacing: size * 0.025,
        color: color ?? p.zinc.s500,
      );

  /// 표 머리글 (.table-head): 11px 고정폭, 자간 더 넓게
  static TextStyle tableHead(AppPalette p, {Color? color}) => TextStyle(
    fontFamily: kMono,
    fontFamilyFallback: _monoFallback,
    fontSize: 11,
    letterSpacing: 0.55,
    color: color ?? p.zinc.s500,
  );

  /// 묶음 이름 (.nav-group-label): 10px 고정폭, 자간 0.16em, zinc-600
  static TextStyle groupLabel(AppPalette p) => TextStyle(
    fontFamily: kMono,
    fontFamilyFallback: _monoFallback,
    fontSize: 10.5,
    letterSpacing: 1.6,
    color: p.zinc.s500,
  );

  /// 섹션 제목 (.section-title): 15px semibold white, 자간 좁게
  static TextStyle sectionTitle(AppPalette p) => TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.375,
    color: p.white,
  );

  /// 통계 카드 제목 (.stat-label): 13px medium zinc-300
  static TextStyle statLabel(AppPalette p) => TextStyle(
    fontFamily: kSans,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.325,
    color: p.zinc.s300,
  );

  /// 페이지 제목 (상단 바): 18px semibold
  static TextStyle pageTitle(AppPalette p) => TextStyle(
    fontFamily: kSans,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: p.white,
  );

  /// 본문 14px
  static TextStyle body(
    AppPalette p, {
    double size = 14,
    Color? color,
    FontWeight? weight,
  }) => TextStyle(
    fontFamily: kSans,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w400,
    height: 1.35,
    color: color ?? p.zinc.s100,
  );

  /// 숫자 (.num): 고정폭 숫자. 큰 금액은 가는 굵기로
  static TextStyle num(
    AppPalette p, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: kSans,
    fontSize: size,
    fontWeight: weight,
    height: 1.25,
    letterSpacing: letterSpacing ?? (size >= 20 ? -size * 0.025 : 0),
    fontFeatures: _tabular,
    color: color ?? p.white,
  );

  /// 큰 숫자 (대표 금액): 가는 굵기, 자간 좁게
  static TextStyle bigNumber(AppPalette p, {double size = 30, Color? color}) =>
      num(
        p,
        size: size,
        weight: FontWeight.w300,
        color: color,
        letterSpacing: -size * 0.025,
      );
}
