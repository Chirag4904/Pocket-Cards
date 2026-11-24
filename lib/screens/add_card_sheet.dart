import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../provider/card_provider.dart';
import '../provider/wallet_provider.dart';
import '../services/app_services.dart';
import '../services/card_scanner.dart';
import '../theme/app_theme.dart';
import '../theme/card_skins.dart';
import '../utils/formatters.dart';
import '../widgets/bill_reminder_picker.dart';
import '../widgets/skin_picker.dart';
import '../widgets/ui_kit.dart';
import '../widgets/wallet_card_view.dart';
import 'scan_card_sheet.dart';

Future<void> showAddCardSheet(BuildContext context) async {
  final form = context.read<CardProvider>()..clearFields();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AddCardSheet(),
  );
  form.clearFields();
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cvvFocus = FocusNode();
  bool _saving = false;
  bool _canScan = false;
  String? _scanNote;

  @override
  void initState() {
    super.initState();
    // Flip the preview to its back while the CVV is being typed.
    _cvvFocus.addListener(() => setState(() {}));
    CardScanner.isSupported().then((ok) {
      if (mounted && ok) setState(() => _canScan = true);
    });
  }

  Future<void> _scan(CardProvider form) async {
    Haptics.tap();
    FocusScope.of(context).unfocus();
    final card = await showCardScanSheet(context);
    if (card == null || !mounted) return;
    form.fillFromScan(
      number: card.number.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim(),
      expiry: card.expiry,
      holder: card.holder,
    );
    final missing = [
      if (card.holder == null) 'name',
      if (card.expiry == null) 'expiry',
      'CVV',
      if (form.selectedBank.isEmpty) 'bank',
    ];
    setState(() => _scanNote = 'Read from the card. Add the ${_list(missing)} yourself.');
  }

  static String _list(List<String> items) => items.length == 1
      ? items.first
      : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

  @override
  void dispose() {
    _cvvFocus.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      floatingLabelStyle: const TextStyle(color: AppColors.lime),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(Colors.transparent),
      enabledBorder: border(AppColors.stroke),
      focusedBorder: border(AppColors.lime, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    );
  }

  Future<void> _save(CardProvider form) async {
    if (_saving || !_formKey.currentState!.validate()) {
      Haptics.warn();
      return;
    }
    setState(() => _saving = true);
    await context.read<WalletProvider>().add(
          number: form.cardNumber,
          holder: form.cardHolderName.trim(),
          expiry: form.expiryDate,
          cvv: form.cvv,
          bank: form.selectedBank,
          skinId: form.skinId,
          limit: form.cardBalance,
          logoStyle: form.logoStyle,
          billDay: form.billDay,
          remindDaysBefore: form.remindDaysBefore,
        );
    Haptics.flip();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<CardProvider>();
    final wallet = context.read<WalletProvider>();
    final banks = wallet.bankCodes.keys.toList()..sort();
    const fieldText = TextStyle(
        fontFamily: 'SpaceGrotesk', color: AppColors.textPrimary, fontSize: 16);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('New card', style: AppText.title)),
              GlassIconButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: const [
              Icon(Icons.lock_rounded, size: 14, color: AppColors.lime),
              SizedBox(width: 6),
              Text('Encrypted on this device. Never online.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 20),
            InteractiveCard(
              revealed: true,
              flipped: _cvvFocus.hasFocus,
              data: CardFaceData(
                skin: CardSkins.resolve(form.skinId),
                digits: form.cardNumber.replaceAll(RegExp(r'\D'), ''),
                holder: form.cardHolderName,
                expiry: form.expiryDate,
                cvv: form.cvv,
                bankName: form.selectedBank,
                logoAsset: wallet.logoAssetFor(form.selectedBank),
                logoStyle: form.logoStyle,
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Pick a vibe'),
            SkinPicker(selected: form.skinId, onChanged: form.setSkinId),
            const SizedBox(height: 18),
            const SectionLabel('Card details'),
            if (_canScan) ...[
              _ScanButton(onTap: () => _scan(form)),
              if (_scanNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.lime),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_scanNote!, style: AppText.mono.copyWith(height: 1.4))),
                  ]),
                ),
              const SizedBox(height: 14),
            ],
            Form(
              key: _formKey,
              child: Column(children: [
                DropdownButtonFormField<String>(
                  value: form.selectedBank.isEmpty ? null : form.selectedBank,
                  isExpanded: true,
                  menuMaxHeight: 380,
                  dropdownColor: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  style: fieldText,
                  iconEnabledColor: AppColors.textSecondary,
                  decoration: _decoration('Bank', Icons.account_balance_outlined),
                  items: [
                    for (final bank in banks)
                      DropdownMenuItem(
                        value: bank,
                        child: Text(bank, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) form.setSelectedBank(v);
                  },
                  validator: (v) => v == null ? 'Pick your bank' : null,
                ),
                AnimatedSize(
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  child: wallet.logoAssetFor(form.selectedBank) == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionLabel('Logo on card'),
                            LogoStylePicker(selected: form.logoStyle, onChanged: form.setLogoStyle),
                          ]),
                        ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: ValueKey('number-${form.fillGeneration}'),
                  initialValue: form.cardNumber,
                  style: fieldText.copyWith(letterSpacing: 1.5, fontFeatures: AppText.tabular),
                  decoration: _decoration('Card number', Icons.credit_card_rounded,
                      hint: '0000 0000 0000 0000'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    CardNumberInputFormatter(),
                  ],
                  onChanged: form.setCardNumber,
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\s+'), '');
                    if (digits.isEmpty) return 'Enter the card number';
                    if (digits.length != 16) return 'Card number must be 16 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: ValueKey('holder-${form.fillGeneration}'),
                  initialValue: form.cardHolderName,
                  style: fieldText,
                  decoration: _decoration('Name on card', Icons.person_outline_rounded),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: form.setCardHolderName,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter the name on the card' : null,
                ),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('expiry-${form.fillGeneration}'),
                      initialValue: form.expiryDate,
                      style: fieldText,
                      decoration: _decoration('Expiry', Icons.event_outlined, hint: 'MM/YY'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        ExpiryDateInputFormatter(),
                      ],
                      onChanged: form.setExpiryDate,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter expiry';
                        if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(v)) {
                          return 'Use MM/YY';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: form.cvv,
                      focusNode: _cvvFocus,
                      obscureText: true,
                      obscuringCharacter: '•',
                      style: fieldText,
                      decoration: _decoration('CVV', Icons.lock_outline_rounded, hint: '•••'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: form.setCVV,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter CVV';
                        if (v.length < 3) return '3–4 digits';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue:
                      form.cardBalance == 0 ? '' : form.cardBalance.toInt().toString(),
                  style: fieldText,
                  decoration: _decoration('Card limit (optional)', Icons.currency_rupee_rounded,
                      hint: 'Skip if you like'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => form.setCardBalance(double.tryParse(v) ?? 0),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            const SectionLabel('Bill reminder · optional'),
            BillReminderPicker(
              billDay: form.billDay,
              remindDaysBefore: form.remindDaysBefore,
              onChanged: form.setBilling,
            ),
            const SizedBox(height: 26),
            GradientButton(
              label: _saving ? 'Saving…' : 'Add to wallet',
              icon: Icons.add_card_rounded,
              onPressed: () => _save(form),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.lime.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lime.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lime),
            child: const Icon(Icons.contactless_outlined, color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Scan card with NFC',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SizedBox(height: 2),
              Text('Tap it on your phone to fill the number and expiry',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ]),
      ),
    );
  }
}
