import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/assets/assets_screen.dart';
import 'screens/dividends/dividends_screen.dart';
import 'screens/home/home_screen.dart';
import 'widgets/ui/app_icon.dart';
import 'widgets/ui/app_shell.dart';

void main() {
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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: StockManagerApp()));
}

class StockManagerApp extends StatelessWidget {
  const StockManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainNavigation(),
    );
  }
}

// 하단 탭 = 데스크톱 사이드바 메뉴 묶음 (홈 · 자산 · 배당)
const _tabs = [
  AppTab('홈', AppGlyph.home),
  AppTab('자산', AppGlyph.wallet),
  AppTab('배당', AppGlyph.coin),
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
    ];

    return Scaffold(
      // 본문이 하단 탭 뒤로 흐리게 지나가도록 (목록은 MediaQuery 아래 여백으로 피한다)
      extendBody: true,
      backgroundColor: AppColors.background,
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
