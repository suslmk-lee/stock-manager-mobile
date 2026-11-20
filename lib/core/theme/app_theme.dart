import 'package:flutter/material.dart';
import 'palette.dart';
import 'themes.dart';
import 'typography.dart';

/// 예전 화면(추가·수정 시트 등)이 쓰던 색 이름을 지금 테마 색으로 옮긴 것.
/// `context.colors.primary` 처럼 쓴다. 새 화면은 `context.pal` 을 쓴다.
class AppColors {
  final AppPalette p;

  const AppColors(this.p);

  // 바탕
  Color get background => p.ink950;
  Color get surface => p.surface;
  Color get surfaceHigh => p.ink700;

  // 강조 (테마 강조색)
  Color get primary => p.mint.s400;
  Color get primaryDim => p.mint.s400.withValues(alpha: 0.15);

  /// 강조색 면 위 글자 (다크 = 어두운 바탕색, 라이트 = 흰색)
  Color get onPrimary => p.isDark ? p.ink950 : p.paper;
  Color get secondary => p.sky.s400;
  Color get secondaryDim => p.sky.s400.withValues(alpha: 0.15);

  // 글자
  Color get textPrimary => p.white;
  Color get textSecondary => p.zinc.s400;

  // 상태: 오르면 강조색, 내리면 rose
  Color get positive => p.mint.s300;
  Color get negative => p.rose.s400;

  // 테두리: 글자색 8%
  Color get border => p.w(0.08);
}

extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors(pal);
}

class AppTheme {
  static ThemeData get dark => fromPalette(AppPalette.defaultDark);

  static final _cache = <String, ThemeData>{};

  /// 테마 목록의 테마 하나 → ThemeData (한 번 만든 것은 다시 쓴다)
  static ThemeData of(AppThemeDef def) =>
      _cache[def.id] ??= fromPalette(def.palette);

  /// 주 버튼 색: 다크는 밝은 면 + 어두운 글자, 라이트는 강조색 면 + 흰 글자
  /// (데스크톱 card-styles.css 의 라이트 테마 주 버튼과 같다)
  static (Color bg, Color fg) primaryButtonColors(AppPalette p) =>
      p.isDark ? (p.zinc.s100, p.ink950) : (p.mint.s400, p.paper);

  static ThemeData fromPalette(AppPalette p) {
    final (buttonBg, buttonFg) = primaryButtonColors(p);
    // 강조색 면 위 글자: 다크 테마는 강조색이 밝아서 어두운 글자, 라이트는 흰 글자
    final onAccent = p.isDark ? p.ink950 : p.paper;
    final base = ThemeData(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      fontFamily: kSans,
      useMaterial3: true,
    );
    final radius12 = BorderRadius.circular(12);
    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.ink950,
      canvasColor: p.ink950,
      colorScheme: ColorScheme(
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        primary: p.mint.s400,
        onPrimary: onAccent,
        secondary: p.sky.s400,
        onSecondary: onAccent,
        error: p.rose.s400,
        onError: onAccent,
        surface: p.surface,
        onSurface: p.zinc.s100,
        surfaceContainerHighest: p.ink700,
        outline: p.w(0.14),
        outlineVariant: p.w(0.08),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: kSans,
        bodyColor: p.zinc.s100,
        displayColor: p.white,
      ),
      dividerColor: p.w(0.07),
      dividerTheme: DividerThemeData(color: p.w(0.07), thickness: 1, space: 1),
      splashFactory: InkRipple.splashFactory,
      highlightColor: p.w(0.03),
      splashColor: p.w(0.05),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.pageTitle(p),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.mint.s400,
        linearTrackColor: p.w(0.06),
        circularTrackColor: Colors.transparent,
      ),
      // 입력 (.input-field): 흰 3.5% 바탕, 흰 10% 테두리, 초점은 강조색 50%
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.w(0.035),
        hintStyle: TextStyle(color: p.zinc.s600),
        labelStyle: TextStyle(color: p.zinc.s400),
        floatingLabelStyle: TextStyle(color: p.mint.s300),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: inputBorder(p.w(0.1)),
        enabledBorder: inputBorder(p.w(0.1)),
        focusedBorder: inputBorder(p.mint.s400.withValues(alpha: 0.5), 1.5),
        errorBorder: inputBorder(p.rose.s400.withValues(alpha: 0.6)),
        focusedErrorBorder: inputBorder(p.rose.s400, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.mint.s400,
        selectionColor: p.mint.s400.withValues(alpha: 0.3),
        selectionHandleColor: p.mint.s400,
      ),
      // 주 버튼 (.btn-primary): 알약형, 밝은 면 + 어두운 글자
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: buttonFg,
          disabledBackgroundColor: p.w(0.12),
          disabledForegroundColor: p.zinc.s500,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(
            fontFamily: kSans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.zinc.s200,
          textStyle: const TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.zinc.s100,
          side: BorderSide(color: p.w(0.14)),
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.zinc.s400),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonBg,
        foregroundColor: buttonFg,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: p.black.withValues(alpha: 0.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.ink800,
        surfaceTintColor: Colors.transparent,
        barrierColor: p.black.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.w(0.08)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: p.white,
        ),
        contentTextStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 14,
          color: p.zinc.s300,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.ink800,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius12,
          side: BorderSide(color: p.w(0.08)),
        ),
        textStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 14,
          color: p.zinc.s100,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink700,
        contentTextStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 14,
          color: p.zinc.s100,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: radius12,
          side: BorderSide(color: p.w(0.1)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.ink800,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.ink700,
        headerForegroundColor: p.white,
      ),
    );
  }
}
