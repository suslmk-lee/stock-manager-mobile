import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/asset.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/error_retry.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final assetsAsync = ref.watch(assetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(assetsProvider);
        },
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(accountsProvider),
          ),
          data: (accounts) => assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetry(
              message: e.toString(),
              onRetry: () => ref.invalidate(assetsProvider),
            ),
            data: (assets) {
              if (accounts.isEmpty) {
                return _EmptyAccounts(onAdd: () => showAccountSheet(context));
              }

              final metrics = {
                for (final account in accounts)
                  account.id: _AccountMetrics.fromAssets(account.id, assets),
              };

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _AccountsSummaryHeaderDelegate(
                      accounts: accounts,
                      metrics: metrics,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: accounts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final account = accounts[index];
                        return _AccountCard(
                          account: account,
                          metrics:
                              metrics[account.id] ??
                              const _AccountMetrics.empty(),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAccountSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

void showAccountSheet(BuildContext context, {Account? account}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountSheet(account: account),
  );
}

class _AccountMetrics {
  final int holdingCount;
  final double costBasis;
  final List<String> tickers;

  const _AccountMetrics({
    required this.holdingCount,
    required this.costBasis,
    required this.tickers,
  });

  const _AccountMetrics.empty()
    : holdingCount = 0,
      costBasis = 0,
      tickers = const [];

  factory _AccountMetrics.fromAssets(int accountId, List<Asset> assets) {
    final tickers = <String>[];
    var costBasis = 0.0;

    for (final asset in assets) {
      final holdings = asset.holdings.where((h) => h.accountId == accountId);
      for (final holding in holdings) {
        tickers.add(asset.ticker);
        costBasis += holding.quantity * holding.averagePrice;
      }
    }

    return _AccountMetrics(
      holdingCount: tickers.length,
      costBasis: costBasis,
      tickers: tickers.take(4).toList(),
    );
  }
}

class _AccountsSummaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Account> accounts;
  final Map<int, _AccountMetrics> metrics;

  const _AccountsSummaryHeaderDelegate({
    required this.accounts,
    required this.metrics,
  });

  @override
  double get minExtent => 132;

  @override
  double get maxExtent => 132;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _AccountsSummaryBar(accounts: accounts, metrics: metrics),
    );
  }

  @override
  bool shouldRebuild(covariant _AccountsSummaryHeaderDelegate oldDelegate) {
    return oldDelegate.accounts != accounts || oldDelegate.metrics != metrics;
  }
}

class _AccountsSummaryBar extends StatelessWidget {
  final List<Account> accounts;
  final Map<int, _AccountMetrics> metrics;

  const _AccountsSummaryBar({required this.accounts, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final domestic = accounts.where((a) => a.marketType == 'Domestic').length;
    final international = accounts.length - domestic;
    final holdingCount = metrics.values.fold<int>(
      0,
      (sum, metric) => sum + metric.holdingCount,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22263A), Color(0xFF151826)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34384D)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '계좌 현황',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SummaryStat(label: '계좌', value: '${accounts.length}'),
                    const _SummaryDivider(),
                    _SummaryStat(label: '보유', value: '$holdingCount'),
                    const _SummaryDivider(),
                    _SummaryStat(
                      label: '국내/해외',
                      value: '$domestic/$international',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;
  final _AccountMetrics metrics;

  const _AccountCard({required this.account, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInternational = account.marketType == 'International';
    final accent = isInternational ? AppColors.primary : AppColors.positive;
    final logoAsset = _brokerLogoAsset(account.broker);
    final costText = account.currency == 'KRW'
        ? '₩${NumberFormat('#,###').format(metrics.costBasis.round())}'
        : '\$${NumberFormat('#,##0.00').format(metrics.costBasis)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showAccountSheet(context, account: account),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _BrokerLogoBadge(
                    logoAsset: logoAsset,
                    fallbackIcon: isInternational
                        ? Icons.public_rounded
                        : Icons.apartment_rounded,
                    fallbackColor: accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            account.broker,
                            _maskedAccountNumber(account.accountNumber),
                          ].where((v) => v.trim().isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.surfaceHigh,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        showAccountSheet(context, account: account);
                      }
                      if (value == 'delete') {
                        await _deleteAccount(context, ref, account);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _InfoPill(
                    label: isInternational ? '해외' : '국내',
                    color: accent,
                    background: isInternational
                        ? AppColors.primaryDim
                        : const Color(0x3322C55E),
                  ),
                  const SizedBox(width: 8),
                  _InfoPill(
                    label: account.currency,
                    color: AppColors.textPrimary,
                    background: AppColors.surfaceHigh,
                  ),
                  const Spacer(),
                  Text(
                    '${metrics.holdingCount}종목',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    costText,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (metrics.tickers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: metrics.tickers
                        .map((ticker) => _TickerChip(ticker: ticker))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrokerLogoBadge extends StatelessWidget {
  final String? logoAsset;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const _BrokerLogoBadge({
    required this.logoAsset,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    const outer = Color(0x332E3340);
    const inner = Color(0xFFE8ECF2);
    const border = Color(0x667C8494);

    return Container(
      width: 96,
      height: 48,
      decoration: BoxDecoration(
        color: outer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Container(
          width: 76,
          height: 34,
          decoration: BoxDecoration(
            color: inner,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: logoAsset == null
                ? Icon(fallbackIcon, color: fallbackColor, size: 20)
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    child: Image.asset(
                      logoAsset!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(fallbackIcon, color: fallbackColor, size: 20),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _InfoPill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  final String ticker;

  const _TickerChip({required this.ticker});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF202431),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        ticker,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAccounts({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          size: 42,
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '계좌가 없습니다',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '자산과 배당을 연결할 계좌를 먼저 추가해 주세요',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('계좌 추가'),
        ),
      ],
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  final Account? account;

  const _AccountSheet({this.account});

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brokerCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _marketType;
  late String _currency;
  bool _submitting = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameCtrl = TextEditingController(text: account?.name ?? '');
    _brokerCtrl = TextEditingController(text: account?.broker ?? '');
    _numberCtrl = TextEditingController(text: account?.accountNumber ?? '');
    _descriptionCtrl = TextEditingController(text: account?.description ?? '');
    _marketType = account?.marketType == 'International'
        ? 'International'
        : 'Domestic';
    _currency =
        account?.currency ?? (_marketType == 'International' ? 'USD' : 'KRW');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brokerCtrl.dispose();
    _numberCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _brokerCtrl.text.trim().isEmpty) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'broker': _brokerCtrl.text.trim(),
        'account_number': _numberCtrl.text.trim(),
        'market_type': _marketType,
        'currency': _currency,
        'description': _descriptionCtrl.text.trim(),
      };
      final api = ref.read(apiServiceProvider);
      if (_isEditing) {
        await api.updateAccount(widget.account!.id, payload);
      } else {
        await api.createAccount(payload);
      }

      ref.invalidate(accountsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '계좌를 수정했습니다' : '계좌를 추가했습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEditing ? '계좌 수정' : '계좌 추가',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _SheetLabel('계좌명'),
            _SheetTextField(controller: _nameCtrl, hint: '주식계좌, IRP ...'),
            const SizedBox(height: 14),
            _SheetLabel('증권사'),
            _SheetTextField(controller: _brokerCtrl, hint: 'KB증권, 미래에셋증권 ...'),
            const SizedBox(height: 14),
            _SheetLabel('계좌번호'),
            _SheetTextField(
              controller: _numberCtrl,
              hint: '선택 입력',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            _SheetLabel('시장'),
            Row(
              children: [
                Expanded(
                  child: _ChoiceButton(
                    label: '국내',
                    selected: _marketType == 'Domestic',
                    onTap: () => setState(() {
                      _marketType = 'Domestic';
                      _currency = 'KRW';
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceButton(
                    label: '해외',
                    selected: _marketType == 'International',
                    onTap: () => setState(() {
                      _marketType = 'International';
                      _currency = 'USD';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SheetLabel('기본 통화'),
            Row(
              children: [
                Expanded(
                  child: _ChoiceButton(
                    label: 'KRW',
                    selected: _currency == 'KRW',
                    onTap: () => setState(() => _currency = 'KRW'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceButton(
                    label: 'USD',
                    selected: _currency == 'USD',
                    onTap: () => setState(() => _currency = 'USD'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SheetLabel('메모'),
            _SheetTextField(
              controller: _descriptionCtrl,
              hint: '선택 입력',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? '수정하기' : '추가하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const _SheetTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDim : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _maskedAccountNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 4) return digits;
  return '•••• ${digits.substring(digits.length - 4)}';
}

String? _brokerLogoAsset(String broker) {
  final normalized = broker
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_·.]'), '')
      .replaceAll('증권', '')
      .replaceAll('투자', '')
      .replaceAll('금융', '');

  if (normalized.contains('kb') || normalized.contains('국민')) {
    return 'assets/brokers/kb.png';
  }
  if (normalized.contains('nh') ||
      normalized.contains('농협') ||
      normalized.contains('나무')) {
    return 'assets/brokers/NH.png';
  }
  if (normalized.contains('미래에셋') || normalized.contains('mirae')) {
    return 'assets/brokers/miraeasset.png';
  }
  if (normalized.contains('삼성') || normalized.contains('samsung')) {
    return 'assets/brokers/samsung.png';
  }
  if (normalized.contains('신한') || normalized.contains('shinhan')) {
    return 'assets/brokers/shinhan.png';
  }
  if (normalized.contains('토스') || normalized.contains('toss')) {
    return 'assets/brokers/toss.png';
  }
  if (normalized.contains('대신') || normalized.contains('daishin')) {
    return 'assets/brokers/daishin.png';
  }
  if (normalized.contains('카카오') || normalized.contains('kakao')) {
    return 'assets/brokers/kakao.png';
  }
  if (normalized.contains('한국') || normalized.contains('korea')) {
    return 'assets/brokers/korea.png';
  }
  if (normalized.contains('메리츠') || normalized.contains('meritz')) {
    return 'assets/brokers/meritz.png';
  }

  return null;
}

Future<void> _deleteAccount(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('계좌 삭제'),
      content: Text('${account.name} 계좌를 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제', style: TextStyle(color: AppColors.negative)),
        ),
      ],
    ),
  );

  if (confirm != true) return;
  try {
    await ref.read(apiServiceProvider).deleteAccount(account.id);
    ref.invalidate(accountsProvider);
    ref.invalidate(assetsProvider);
    ref.invalidate(dividendStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('계좌를 삭제했습니다')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: $e'),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }
}
