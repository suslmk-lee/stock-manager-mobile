import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/asset.dart';
import '../../models/dividend.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../services/api_service.dart';

void showAddDividendSheet(BuildContext context, {Dividend? dividend}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddDividendSheet(dividend: dividend),
  );
}

class _AddDividendSheet extends ConsumerStatefulWidget {
  const _AddDividendSheet({this.dividend});

  final Dividend? dividend;

  @override
  ConsumerState<_AddDividendSheet> createState() => _AddDividendSheetState();
}

class _AddDividendSheetState extends ConsumerState<_AddDividendSheet> {
  final _amountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  final _assetSearchCtrl = TextEditingController();

  Account? _selectedAccount;
  Asset? _selectedAsset;
  String _currency = 'USD';
  DateTime _date = DateTime.now();
  bool _submitting = false;

  bool get _isEditing => widget.dividend != null;

  @override
  void initState() {
    super.initState();
    if (widget.dividend != null) {
      final dividend = widget.dividend!;
      _amountCtrl.text = dividend.amount.toString();
      _taxCtrl.text = dividend.tax.toString();
      _date = DateTime.tryParse(dividend.date) ?? DateTime.now();
      _currency = dividend.currency;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _taxCtrl.dispose();
    _assetSearchCtrl.dispose();
    super.dispose();
  }

  Account? _resolveAccount(List<Account> accounts) {
    if (_selectedAccount != null) return _selectedAccount;
    final id = widget.dividend?.accountId;
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Asset? _resolveAsset(List<Asset> assets) {
    if (_selectedAsset != null) return _selectedAsset;
    final id = widget.dividend?.assetId;
    if (id == null) return null;
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  /// 선택된 계좌 기준 + 검색어 필터
  List<Asset> _filteredAssets(List<Asset> all, Account? account) {
    final query = _assetSearchCtrl.text.trim().toLowerCase();
    var list = account == null
        ? all
        : all.where((a) => a.holdings.any((h) => h.accountId == account.id)).toList();
    if (query.isNotEmpty) {
      list = list
          .where((a) =>
              a.ticker.toLowerCase().contains(query) ||
              a.name.toLowerCase().contains(query))
          .toList();
    }
    return list;
  }

  void _selectAsset(Asset asset) {
    setState(() {
      _selectedAsset = asset;
      _assetSearchCtrl.text = '';
      final isKorean =
          asset.ticker.endsWith('.KS') || asset.ticker.endsWith('.KQ');
      _currency = isKorean ? 'KRW' : 'USD';
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit(Account? account, Asset? asset) async {
    final amount = double.tryParse(_amountCtrl.text);
    final tax = double.tryParse(_taxCtrl.text) ?? 0;

    if (amount == null || amount <= 0 || account == null || asset == null) return;

    setState(() => _submitting = true);
    try {
      final payload = {
        'account_id': account.id,
        'asset_id': asset.id,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'amount': amount,
        'tax': tax,
        'currency': _currency,
        'is_received': true,
      };

      final api = ref.read(apiServiceProvider);
      if (_isEditing) {
        await api.updateDividend(widget.dividend!.id, payload);
      } else {
        await api.createDividend(payload);
      }

      ref.invalidate(dividendStatsProvider);
      ref.invalidate(recentDividendsProvider);
      ref.invalidate(monthlyDividendsProvider);
      ref.invalidate(allDividendsProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '수정 실패: $e' : '저장 실패: $e'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _canSubmit(Account? account, Asset? asset) =>
      account != null && asset != null && _amountCtrl.text.isNotEmpty && !_submitting;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    Account? currentAccount;
    Asset? currentAsset;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
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
              _isEditing ? '배당금 수정' : '배당금 추가',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // 계좌 선택
            const _Label('계좌'),
            const SizedBox(height: 8),
            accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (accounts) {
                currentAccount = _resolveAccount(accounts);
                return _DarkDropdown<Account>(
                  value: currentAccount,
                  hint: '계좌 선택',
                  items: accounts,
                  itemLabel: (a) => '${a.broker} · ${a.name}',
                  onChanged: (a) => setState(() {
                    _selectedAccount = a;
                    _selectedAsset = null;
                    _assetSearchCtrl.clear();
                  }),
                );
              },
            ),
            const SizedBox(height: 20),

            // 종목 검색
            const _Label('종목'),
            const SizedBox(height: 8),
            assetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (allAssets) {
                currentAsset = _resolveAsset(allAssets);

                if (currentAsset != null && _assetSearchCtrl.text.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SelectedAssetChip(
                        asset: currentAsset!,
                        onClear: () => setState(() {
                          _selectedAsset = null;
                          _assetSearchCtrl.clear();
                        }),
                      ),
                    ],
                  );
                }

                final filtered = _filteredAssets(allAssets, currentAccount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _assetSearchCtrl,
                      enabled: currentAccount != null,
                      style:
                          const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: currentAccount == null
                            ? '계좌를 먼저 선택하세요'
                            : '티커 또는 종목명 검색...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        prefixIcon:
                            const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                        suffixIcon: _assetSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textSecondary, size: 18),
                                onPressed: () => setState(() => _assetSearchCtrl.clear()),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceHigh,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    if (_assetSearchCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  '검색 결과 없음',
                                  style: TextStyle(
                                      color: AppColors.textSecondary, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                  color: AppColors.border,
                                  height: 1,
                                  indent: 14,
                                  endIndent: 14,
                                ),
                                itemBuilder: (_, i) {
                                  final asset = filtered[i];
                                  final isKorean = asset.ticker.endsWith('.KS') ||
                                      asset.ticker.endsWith('.KQ');
                                  return InkWell(
                                    onTap: () => _selectAsset(asset),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryDim,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                isKorean
                                                    ? asset.name.substring(
                                                        0,
                                                        asset.name.length > 2
                                                            ? 2
                                                            : asset.name.length)
                                                    : (asset.ticker.length > 4
                                                        ? asset.ticker.substring(0, 4)
                                                        : asset.ticker),
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isKorean ? asset.name : asset.ticker,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  isKorean ? asset.ticker : asset.name,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // 통화 + 금액
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('통화'),
                    const SizedBox(height: 8),
                    Row(
                      children: ['USD', 'KRW'].map((c) {
                        final selected = _currency == c;
                        return GestureDetector(
                          onTap: () => setState(() => _currency = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primaryDim : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? AppColors.primary : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                color: selected ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('배당금액'),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _amountCtrl,
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 세금
            const _Label('세금 (원천징수)'),
            const SizedBox(height: 8),
            _DarkTextField(
              controller: _taxCtrl,
              hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
            const SizedBox(height: 20),

            // 날짜
            const _Label('수령일'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('yyyy년 MM월 dd일').format(_date),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 추가/수정 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _canSubmit(currentAccount, currentAsset)
                    ? () => _submit(currentAccount, currentAsset)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.background,
                        ),
                      )
                    : Text(
                        _isEditing ? '수정하기' : '추가하기',
                        style:
                            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 선택된 종목 칩
class _SelectedAssetChip extends StatelessWidget {
  final Asset asset;
  final VoidCallback onClear;
  const _SelectedAssetChip({required this.asset, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final isKorean = asset.ticker.endsWith('.KS') || asset.ticker.endsWith('.KQ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                isKorean
                    ? asset.name.substring(0, asset.name.length > 2 ? 2 : asset.name.length)
                    : (asset.ticker.length > 4 ? asset.ticker.substring(0, 4) : asset.ticker),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKorean ? asset.name : asset.ticker,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isKorean ? asset.ticker : asset.name,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 20),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}

class _DarkDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceHigh,
          hint: Text(hint, style: const TextStyle(color: AppColors.textSecondary)),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _DarkTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
