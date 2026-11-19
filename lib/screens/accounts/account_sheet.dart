import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../services/api_service.dart';

// 계좌 추가·수정 시트와 삭제. 계좌 목록은 자산 탭(screens/assets/accounts_view.dart)에 있다.

void showAccountSheet(BuildContext context, {Account? account}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountSheet(account: account),
  );
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

Future<void> deleteAccount(
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
