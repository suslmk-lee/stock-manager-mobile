import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_manager/core/theme/app_theme.dart';
import 'package:stock_manager/core/theme/themes.dart';
import 'package:stock_manager/providers/settings_provider.dart';
import 'package:stock_manager/services/cache_service.dart';

Future<ProviderContainer> makeContainer([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('테마 목록', () {
    test('데스크톱과 같은 21종 (다크 16 · 라이트 5), id 는 겹치지 않는다', () {
      expect(kThemes, hasLength(21));
      expect(kThemes.where((t) => t.dark), hasLength(16));
      expect(kThemes.map((t) => t.id).toSet(), hasLength(kThemes.length));
      expect(kThemes.first.id, kDefaultThemeId);
    });

    test('모르는 id 는 기본 테마로', () {
      expect(themeById('no-such-theme').id, kDefaultThemeId);
      expect(themeById(null).id, kDefaultThemeId);
    });

    test('상태 색 덮어쓰기와 라이트 테마 주 버튼 색', () {
      final gruvbox = themeById('gruvbox').palette;
      expect(gruvbox.rose.s400, isNot(themeById('default').palette.rose.s400));

      final light = themeById('light').palette;
      expect(light.isDark, isFalse);
      final (bg, fg) = AppTheme.primaryButtonColors(light);
      expect(bg, light.mint.s400); // 라이트: 강조색 면 + 흰 글자
      expect(fg, const Color(0xFFFFFFFF));
      expect(AppTheme.of(themeById('light')).brightness, Brightness.light);
    });
  });

  group('설정', () {
    test('처음에는 기본값 (기본 테마 · 보통 · 시작 화면 켬)', () async {
      final c = await makeContainer();
      final s = c.read(settingsProvider);
      expect(s.themeId, kDefaultThemeId);
      expect(s.fontSize, FontSizeOption.md);
      expect(s.fontSize.scale, 1);
      expect(s.showIntro, isTrue);
    });

    test('바꾼 값은 저장되어 다음 실행에도 남는다', () async {
      final c = await makeContainer();
      final n = c.read(settingsProvider.notifier);
      n.setTheme('nord');
      n.setFontSize(FontSizeOption.lg);
      n.setShowIntro(false);

      final prefs = c.read(sharedPrefsProvider);
      final next = await makeContainer({
        for (final k in prefs.getKeys()) k: prefs.get(k)!,
      });
      final s = next.read(settingsProvider);
      expect(s.themeId, 'nord');
      expect(s.fontSize, FontSizeOption.lg);
      expect(s.fontSize.scale, closeTo(17 / 16, 1e-9));
      expect(s.showIntro, isFalse);
    });

    test('저장된 테마가 없어진 테마면 기본 테마로', () async {
      final c = await makeContainer({
        'settings_theme': 'removed-theme',
        'settings_font_size': 'huge',
      });
      final s = c.read(settingsProvider);
      expect(s.themeId, kDefaultThemeId);
      expect(s.fontSize, FontSizeOption.md);
    });
  });

  test('캐시 지우기는 cache_* 만 지우고 설정은 남긴다', () async {
    SharedPreferences.setMockInitialValues({
      'cache_assets': '{"data":[],"timestamp":0}',
      'cache_account_dividends_3': '{"data":[1,2],"timestamp":0}',
      'settings_theme': 'nord',
    });
    final cache = CacheService();

    final before = await cache.stats();
    expect(before.count, 2);
    expect(before.bytes, greaterThan(0));

    expect(await cache.clearAll(), 2);
    expect((await cache.stats()).count, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_theme'), 'nord');
  });
}
