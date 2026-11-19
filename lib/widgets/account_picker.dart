import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import '../models/account.dart';
import 'ui/app_icon.dart';
import 'ui/controls.dart';
import 'ui/logos.dart';

// 계좌 고르기: 계좌가 많아도 한 화면에서 고르도록 가로 탭 대신 바텀시트로 보여 준다.
// (데스크톱의 '증권사 로고가 있는 계좌 목록'과 같은 모양)

class AccountPickItem {
  final Account account;

  /// 오른쪽 위 (예: 평가금액)
  final String? value;

  /// 오른쪽 아래 (예: 37종목, 12건)
  final String? meta;

  const AccountPickItem({required this.account, this.value, this.meta});
}

/// 고른 결과. id 가 null 이면 '전체 계좌'
class AccountChoice {
  final int? id;

  const AccountChoice(this.id);
}

Future<AccountChoice?> showAccountPicker(
  BuildContext context, {
  required List<AccountPickItem> items,
  required int? selectedId,
  String? allMeta,
}) {
  return showModalBottomSheet<AccountChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountPickerSheet(
      items: items,
      selectedId: selectedId,
      allMeta: allMeta,
    ),
  );
}

enum _Market { all, domestic, international }

class _AccountPickerSheet extends StatefulWidget {
  final List<AccountPickItem> items;
  final int? selectedId;
  final String? allMeta;

  const _AccountPickerSheet({
    required this.items,
    required this.selectedId,
    this.allMeta,
  });

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  _Market _market = _Market.all;

  bool _isIntl(Account a) => a.marketType == 'International';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final intl = widget.items.where((i) => _isIntl(i.account)).length;
    final domestic = widget.items.length - intl;
    final visible = widget.items.where((i) {
      return switch (_market) {
        _Market.all => true,
        _Market.domestic => !_isIntl(i.account),
        _Market.international => _isIntl(i.account),
      };
    }).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: p.w(0.1))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.w(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '계좌 고르기',
                        style: AppText.body(
                          p,
                          size: 16,
                          weight: FontWeight.w600,
                          color: p.white,
                        ),
                      ),
                    ),
                    GlassSegmented<_Market>(
                      items: [
                        (_Market.all, '전체 ${widget.items.length}'),
                        (_Market.domestic, '국내 $domestic'),
                        (_Market.international, '해외 $intl'),
                      ],
                      selected: _market,
                      onChanged: (m) => setState(() => _market = m),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    _PickRow(
                      selected: widget.selectedId == null,
                      leading: Container(
                        width: 56,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.w(0.1)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [p.ink600, p.ink800],
                          ),
                        ),
                        child: const Center(
                          child: AppIcon(AppGlyph.wallet, size: 18),
                        ),
                      ),
                      title: '전체 계좌',
                      subtitle: widget.allMeta ?? '${widget.items.length}계좌',
                      onTap: () =>
                          Navigator.pop(context, const AccountChoice(null)),
                    ),
                    for (final item in visible)
                      _PickRow(
                        selected: widget.selectedId == item.account.id,
                        leading: BrokerLogo(broker: item.account.broker),
                        title: item.account.name,
                        subtitle: [
                          if (item.account.broker.trim().isNotEmpty)
                            item.account.broker.trim(),
                          if (accountLast4(
                            item.account.accountNumber,
                          ).isNotEmpty)
                            '••${accountLast4(item.account.accountNumber)}',
                        ].join(' · '),
                        value: item.value,
                        meta: item.meta,
                        onTap: () => Navigator.pop(
                          context,
                          AccountChoice(item.account.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final bool selected;
  final Widget leading;
  final String title;
  final String subtitle;
  final String? value;
  final String? meta;
  final VoidCallback onTap;

  const _PickRow({
    required this.selected,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? p.mint.s400.withValues(alpha: 0.08)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: BorderSide(
            color: selected
                ? p.mint.s400.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: selected
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: p.mint.s400, width: 3),
                    ),
                  )
                : null,
            padding: EdgeInsets.fromLTRB(selected ? 9 : 12, 10, 12, 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          p,
                          color: selected ? p.white : p.zinc.s100,
                          weight: selected ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(p),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null || meta != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (value != null)
                        Text(
                          value!,
                          style: AppText.num(p, size: 13.5, color: p.zinc.s200),
                        ),
                      if (meta != null) ...[
                        const SizedBox(height: 2),
                        Text(meta!, style: AppText.label(p)),
                      ],
                    ],
                  ),
                ],
                if (selected) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.check_rounded, size: 18, color: p.mint.s300),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 계좌 고르기 버튼 (.input-field 모양): 지갑 아이콘 또는 고른 계좌의 증권사 로고 + 이름
class AccountSelectButton extends StatelessWidget {
  final Account? selected;
  final int totalCount;
  final VoidCallback onTap;

  const AccountSelectButton({
    super.key,
    required this.selected,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final account = selected;
    return Material(
      color: p.w(0.035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.w(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(account == null ? 12 : 6, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (account == null)
                AppIcon(AppGlyph.wallet, size: 18, color: p.zinc.s300)
              else
                BrokerLogo(broker: account.broker, width: 40, height: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  account?.name ?? '전체 계좌',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(p, color: p.zinc.s100),
                ),
              ),
              if (account == null) ...[
                const SizedBox(width: 6),
                Text('$totalCount', style: AppText.label(p)),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: p.zinc.s500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
