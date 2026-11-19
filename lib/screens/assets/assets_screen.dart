import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../accounts/account_sheet.dart';
import '../portfolio/add_asset_sheet.dart';
import 'accounts_view.dart';
import 'holdings_view.dart';

/// 자산 탭 안의 페이지 (0 = 종목, 1 = 계좌)
final assetsPageProvider = StateProvider<int>((ref) => 0);

/// 자산 탭: 종목 · 계좌 (데스크톱 사이드바의 '자산' 묶음)
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(assetsPageProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: const Text('자산'),
        actions: [
          PrimaryPillButton(
            label: page == 0 ? '종목' : '계좌',
            icon: Icons.add_rounded,
            onPressed: () => page == 0
                ? showAddAssetSheet(context)
                : showAccountSheet(context),
          ),
        ],
        bottom: SubPageTabs(
          labels: const ['종목', '계좌'],
          index: page,
          onChanged: (i) => ref.read(assetsPageProvider.notifier).state = i,
        ),
      ),
      body: IndexedStack(
        index: page,
        children: const [HoldingsView(), AccountsView()],
      ),
    );
  }
}
