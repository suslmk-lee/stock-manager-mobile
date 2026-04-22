import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../widgets/error_retry.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsProvider),
        child: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: e.toString(),
          onRetry: () => ref.invalidate(accountsProvider),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Text('계좌가 없습니다',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, p1) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AccountCard(account: accounts[i]),
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final isInternational = account.marketType == 'International';
    final iconColor = isInternational ? AppColors.primary : AppColors.positive;
    final iconBg = isInternational ? AppColors.primaryDim : const Color(0x3322C55E);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isInternational ? Icons.public : Icons.account_balance,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(account.broker,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              account.currency,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
