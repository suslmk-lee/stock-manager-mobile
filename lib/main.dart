import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'providers/settings_provider.dart';
import 'screens/assets/assets_screen.dart';
import 'screens/dividends/dividends_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/intro/intro_gate.dart';
import 'screens/more/more_screen.dart';
import 'widgets/ui/app_icon.dart';
import 'widgets/ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 함께 넣은 글꼴의 라이선스 (SIL OFL 1.1) — 앱 정보의 라이선스 목록에 나온다
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [
      ('Pretendard', 'assets/fonts/OFL-Pretendard.txt'),
      ('JetBrains Mono', 'assets/fonts/OFL-JetBrainsMono.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(file));
    }
  });

  // 저장된 설정(테마 등)을 먼저 읽어 첫 화면부터 그 테마로 그린다
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const StockManagerApp(),
    ),
  );
}

class StockManagerApp extends ConsumerWidget {
  const StockManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Stock Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(settings.theme),
      builder: (context, child) {
        final p = context.pal;
        final mq = MediaQuery.of(context);
        final iconBrightness = p.isDark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: p.ink950,
            systemNavigationBarIconBrightness: iconBrightness,
          ),
          // 글자 크기 설정은 기기 글자 크기 위에 곱한다
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: _ScaledTextScaler(
                mq.textScaler,
                settings.fontSize.scale,
              ),
            ),
            child: child!,
          ),
        );
      },
      home: IntroGate(
        // 켤 때 한 번만 읽는다 (설정에서 바꿔도 다음 실행부터)
        enabled: ref.read(settingsProvider).showIntro,
        child: const MainNavigation(),
      ),
    );
  }
}

/// 기기 글자 크기 × 앱 글자 크기 설정
class _ScaledTextScaler extends TextScaler {
  final TextScaler base;
  final double factor;

  const _ScaledTextScaler(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

// 하단 탭 = 데스크톱 사이드바 메뉴 묶음 (홈 · 자산 · 배당) + 더보기
const _tabs = [
  AppTab('홈', AppGlyph.home),
  AppTab('자산', AppGlyph.wallet),
  AppTab('배당', AppGlyph.coin),
  AppTab('더보기', AppGlyph.more),
];

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onViewAllDividends: () => setState(() => _currentIndex = 2)),
      const AssetsScreen(),
      const DividendsScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      // 본문이 하단 탭 뒤로 흐리게 지나가도록 (목록은 MediaQuery 아래 여백으로 피한다)
      extendBody: true,
      backgroundColor: context.pal.ink950,
      body: AmbientBackground(
        child: IndexedStack(index: _currentIndex, children: screens),
      ),
      bottomNavigationBar: AppTabBar(
        tabs: _tabs,
        index: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
