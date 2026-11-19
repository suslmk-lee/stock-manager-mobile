import 'package:flutter/material.dart';
import 'palette.dart';
import 'typography.dart';

/// 예전 화면(추가·수정 시트 등)이 쓰는 색 상수.
/// 기본 테마(블랙 · 민트) 토큰 값에 맞춰 두었다. 새 화면은 `context.pal` 을 쓴다.
class AppColors {
  // 바탕
  static const background = Color(0xFF060607); // ink-950
  static const surface = Color(0xFF0D0D0E); // surface
  static const surfaceHigh = Color(0xFF1B1B1C); // ink-700

  // 강조 (테마 강조색)
  static const primary = Color(0xFF7DDFB0); // mint-400
  static const primaryDim = Color(0x267DDFB0); // mint-400 / 15%
  static const secondary = Color(0xFF38BDF8); // sky-400
  static const secondaryDim = Color(0x2638BDF8);

  // 글자
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9B9B9C); // zinc-400

  // 상태: 오르면 강조색, 내리면 rose
  static const positive = Color(0xFFA1E8C6); // mint-300
  static const negative = Color(0xFFFB7185); // rose-400

  // 테두리: 흰색 8%
  static const border = Color(0x14FFFFFF);

  // Legacy compat
  static const white = surface;
  static const primaryLight = primaryDim;
  static const cardBorder = border;
}

class AppTheme {
  static ThemeData get dark => fromPalette(AppPalette.defaultDark);

  static ThemeData fromPalette(AppPalette p) {
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
        onPrimary: p.ink950,
        secondary: p.sky.s400,
        onSecondary: p.ink950,
        error: p.rose.s400,
        onError: p.ink950,
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
          backgroundColor: p.zinc.s100,
          foregroundColor: p.ink950,
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
        backgroundColor: p.zinc.s100,
        foregroundColor: p.ink950,
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
