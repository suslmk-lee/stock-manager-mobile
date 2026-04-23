import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../services/api_service.dart';

void showAddAssetSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AddAssetSheet(),
  );
}

class _AddAssetSheet extends ConsumerStatefulWidget {
  const _AddAssetSheet();

  @override
  ConsumerState<_AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends ConsumerState<_AddAssetSheet> {
  final _tickerCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  Map<String, dynamic>? _tickerInfo;
  bool _lookingUp = false;
  bool _submitting = false;
  String? _lookupError;
  Account? _selectedAccount;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupTicker() async {
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    if (ticker.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _lookupError = null;
      _tickerInfo = null;
    });
    try {
      final info = await ref.read(apiServiceProvider).getTickerInfo(ticker);
      setState(() {
        _tickerInfo = info;
        _tickerCtrl.text = ticker;
      });
    } catch (e) {
      setState(() => _lookupError = '종목을 찾을 수 없습니다');
    } finally {
      setState(() => _lookingUp = false);
    }
  }

  Future<void> _submit() async {
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    final qty = double.tryParse(_qtyCtrl.text);
    final price = double.tryParse(_priceCtrl.text);
    if (ticker.isEmpty ||
        qty == null ||
        qty <= 0 ||
        price == null ||
        price <= 0 ||
        _selectedAccount == null)
      return;

    // await 전에 필요한 값 미리 캡처
    final accountId = _selectedAccount!.id;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final assets = ref.read(assetsProvider).valueOrNull ?? [];

      // 기존 자산 확인
      final existing = assets
          .where((a) => a.ticker.toUpperCase() == ticker)
          .firstOrNull;
      final int assetId;
      if (existing != null) {
        assetId = existing.id;
      } else {
        // 신규 자산 생성 (holding은 createTransaction이 담당)
        final name = _tickerInfo?['name'] ?? ticker;
        final type = _tickerInfo?['type'] ?? 'Stock';
        final sector = _tickerInfo?['sector'];
        final logoUrl = _tickerInfo?['logo_url'] ?? _tickerInfo?['logoUrl'];
        final newAsset = await api.createAsset({
          'ticker': ticker,
          'name': name,
          'type': type,
          if (sector != null) 'sector': sector,
          if (logoUrl != null) 'logo_url': logoUrl,
        });
        assetId = newAsset.id;
      }

      // 매수 거래 기록
      await api.createTransaction({
        'account_id': accountId,
        'asset_id': assetId,
        'type': 'Buy',
        'date': dateStr,
        'price': price,
        'quantity': qty,
        'fee': 0,
      });

      ref.invalidate(assetsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$ticker 추가 완료'),
            backgroundColor: AppColors.positive,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: AppColors.negative,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  bool get _canSubmit =>
      _tickerInfo != null &&
      _selectedAccount != null &&
      _qtyCtrl.text.isNotEmpty &&
      _priceCtrl.text.isNotEmpty &&
      !_submitting;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
            // 핸들
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
            const Text(
              '자산 추가',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // 티커 입력
            const _Label('종목 티커'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DarkTextField(
                    controller: _tickerCtrl,
                    hint: 'AAPL, 005930.KS ...',
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _lookupTicker(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _lookingUp ? null : _lookupTicker,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _lookingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Text(
                            '조회',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),

            // 조회 결과
            if (_lookupError != null) ...[
              const SizedBox(height: 8),
              Text(
                _lookupError!,
                style: const TextStyle(color: AppColors.negative, fontSize: 12),
              ),
            ],
            if (_tickerInfo != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryDim),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDim,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tickerInfo!['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_tickerInfo!['type'] ?? ''}${_tickerInfo!['sector'] != null ? ' · ${_tickerInfo!['sector']}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 계좌 선택
            const _Label('계좌'),
            const SizedBox(height: 8),
            accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Text('계좌 로딩 실패', style: TextStyle(color: AppColors.negative)),
              data: (accounts) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Account>(
                    value: _selectedAccount,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceHigh,
                    hint: const Text(
                      '계좌 선택',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text('${a.broker} · ${a.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (a) => setState(() => _selectedAccount = a),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 수량 + 평균단가
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('수량 (주)'),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _qtyCtrl,
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('평균단가'),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _priceCtrl,
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 매수일
            const _Label('매수일'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('yyyy년 MM월 dd일').format(_date),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 추가 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
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
                    : const Text(
                        '추가하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _DarkTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
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
