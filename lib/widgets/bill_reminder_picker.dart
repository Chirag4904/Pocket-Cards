import 'package:flutter/material.dart';

import '../models/wallet_card.dart';
import '../services/app_services.dart';
import '../services/bill_reminders.dart';
import '../theme/app_theme.dart';

/// Optional bill date (day of month) plus "remind me N days before".
///
/// Turning a reminder on asks for notification permission the first time;
/// if the user declines, the choice is still saved and a hint explains why
/// nothing will appear.
class BillReminderPicker extends StatefulWidget {
  const BillReminderPicker({
    super.key,
    required this.billDay,
    required this.remindDaysBefore,
    required this.onChanged,
    this.previewCard,
  });

  final int? billDay;
  final int? remindDaysBefore;
  final void Function(int? billDay, int? remindDaysBefore) onChanged;

  /// Builds the card to preview a reminder for. When set, a "Send a test
  /// reminder" button appears once a reminder is on.
  final WalletCard Function()? previewCard;

  @override
  State<BillReminderPicker> createState() => _BillReminderPickerState();
}

class _BillReminderPickerState extends State<BillReminderPicker> {
  bool _permissionDenied = false;

  Future<void> _pickDay() async {
    Haptics.tap();
    final day = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true, // size to the grid instead of 9/16 of the screen
      builder: (_) => _DayGrid(selected: widget.billDay),
    );
    if (day == null || !mounted) return;
    // Picking a day for the first time turns on a sensible default reminder.
    final lead = widget.billDay == null ? 5 : widget.remindDaysBefore;
    widget.onChanged(day, lead);
    if (lead != null) _ensurePermission();
  }

  Future<void> _setLead(int? days) async {
    Haptics.tap();
    widget.onChanged(widget.billDay, days);
    if (days != null) _ensurePermission();
  }

  bool _previewSent = false;

  Future<void> _preview() async {
    Haptics.tap();
    final ok = await BillReminders.preview(widget.previewCard!());
    if (!mounted) return;
    setState(() {
      _permissionDenied = !ok;
      _previewSent = ok;
    });
  }

  Future<void> _ensurePermission() async {
    final ok = await BillReminders.requestPermission();
    if (mounted) setState(() => _permissionDenied = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.billDay;
    final lead = widget.remindDaysBefore;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickDay,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            constraints: const BoxConstraints(minHeight: 58),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(children: [
              const Icon(Icons.event_repeat_rounded, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  day == null ? 'Bill date' : 'Bill on the ${BillReminders.ordinal(day)} of every month',
                  style: TextStyle(
                    fontSize: 16,
                    color: day == null ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (day != null)
                IconButton(
                  tooltip: 'Remove bill date',
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                  onPressed: () {
                    Haptics.tap();
                    setState(() => _permissionDenied = false);
                    widget.onChanged(null, null);
                  },
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                ),
            ]),
          ),
        ),
      ),
      AnimatedSize(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        alignment: Alignment.topCenter,
        child: day == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REMIND ME', style: AppText.label),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Chip(label: 'Off', selected: lead == null, onTap: () => _setLead(null)),
                    for (final d in BillReminders.leadTimes)
                      _Chip(
                        label: d == 0 ? 'On the day' : '$d days before',
                        selected: lead == d,
                        onTap: () => _setLead(d),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                      _permissionDenied && lead != null
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_none_rounded,
                      size: 14,
                      color: _permissionDenied && lead != null
                          ? AppColors.danger
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lead == null
                            ? 'No reminder for this card.'
                            : _permissionDenied
                                ? 'Notifications are off for Pocket Cards. Turn them on in Settings to get this reminder.'
                                : 'Every month at ${BillReminders.hour} am, sent by your phone. Nothing goes online.',
                        style: AppText.mono.copyWith(
                          color: _permissionDenied && lead != null ? AppColors.danger : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ]),
                  if (lead != null && widget.previewCard != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _preview,
                      icon: Icon(
                        _previewSent ? Icons.check_rounded : Icons.notifications_active_outlined,
                        size: 18,
                        color: AppColors.lime,
                      ),
                      label: Text(
                        _previewSent ? 'Sent · check the top of your screen' : 'Send a test reminder',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.lime.withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ]),
              ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.lime : AppColors.stroke),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.textSecondary,
            )),
      ),
    );
  }
}

/// 1–31 laid out like a calendar month, in a bottom sheet.
class _DayGrid extends StatelessWidget {
  const _DayGrid({this.selected});
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bill date', style: AppText.title),
          const SizedBox(height: 6),
          const Text('The day of the month your statement is generated.', style: AppText.body),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var d = 1; d <= 31; d++)
                Material(
                  color: d == selected ? AppColors.lime : AppColors.surfaceHigh,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context, d),
                    child: Center(
                      child: Text('$d',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: d == selected ? AppColors.ink : AppColors.textPrimary,
                            fontFeatures: AppText.tabular,
                          )),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Picked 29–31? Shorter months use their last day.', style: AppText.mono),
        ]),
      ),
    );
  }
}
