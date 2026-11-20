import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/themes.dart';

/// 글자 크기 (데스크톱 FONT_SIZES 와 같은 15 · 16 · 17px, 기본 16 = 배율 1)
enum FontSizeOption {
  sm('작게', 15),
  md('보통', 16),
  lg('크게', 17);

  const FontSizeOption(this.label, this.px);

  final String label;
  final double px;

  double get scale => px / 16;
}

@immutable
class AppSettings {
  final String themeId;
  final FontSizeOption fontSize;

  /// 앱을 켤 때 로고 시작 화면을 보여 줄지
  final bool showIntro;

  const AppSettings({
    this.themeId = kDefaultThemeId,
    this.fontSize = FontSizeOption.md,
    this.showIntro = true,
  });

  AppThemeDef get theme => themeById(themeId);

  AppSettings copyWith({
    String? themeId,
    FontSizeOption? fontSize,
    bool? showIntro,
  }) => AppSettings(
    themeId: themeId ?? this.themeId,
    fontSize: fontSize ?? this.fontSize,
    showIntro: showIntro ?? this.showIntro,
  );
}

// 캐시(cache_*)와 겹치지 않는 이름
const _kTheme = 'settings_theme';
const _kFontSize = 'settings_font_size';
const _kShowIntro = 'settings_show_intro';

/// 앱 시작 때 한 번 읽어 main() 에서 넣는다 (첫 화면부터 저장된 테마로 그리려고)
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main() 에서 overrideWithValue 로 넣는다'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final size = prefs.getString(_kFontSize);
    return AppSettings(
      themeId: themeById(prefs.getString(_kTheme)).id,
      fontSize: FontSizeOption.values.firstWhere(
        (f) => f.name == size,
        orElse: () => FontSizeOption.md,
      ),
      showIntro: prefs.getBool(_kShowIntro) ?? true,
    );
  }

  void setTheme(String id) {
    state = state.copyWith(themeId: themeById(id).id);
    _prefs.setString(_kTheme, state.themeId);
  }

  void setFontSize(FontSizeOption size) {
    state = state.copyWith(fontSize: size);
    _prefs.setString(_kFontSize, size.name);
  }

  void setShowIntro(bool show) {
    state = state.copyWith(showIntro: show);
    _prefs.setBool(_kShowIntro, show);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
