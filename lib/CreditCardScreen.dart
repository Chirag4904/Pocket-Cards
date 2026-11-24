import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/wallet_card.dart';
import 'provider/wallet_provider.dart';
import 'screens/add_card_sheet.dart';
import 'screens/arrange_screen.dart';
import 'screens/backup_sheets.dart';
import 'screens/card_detail_screen.dart';
import 'services/app_services.dart';
import 'theme/app_theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/ui_kit.dart';
import 'widgets/wallet_card_view.dart';

export 'utils/formatters.dart';

/// Home: greeting, total limit, and a Wallet-style stack of cards.
class CreditCardScreen extends StatefulWidget {
  const CreditCardScreen({super.key});

  @override
  State<CreditCardScreen> createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends State<CreditCardScreen> {
  /// Stagger card entrances only on the first paint, not on later inserts.
  bool _firstPaint = true;

  /// 0..1 while the list is pulled past the top: the stack fans out a bit,
  /// like pulling apart a stack of real cards.
  final _scroll = ScrollController();
  final _stretch = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scroll.dispose();
    _stretch.dispose();
    super.dispose();
  }

  void _onScroll() {
    final over = _scroll.hasClients ? -_scroll.offset : 0.0;
    final v = (over / 240).clamp(0.0, 1.0);
    if ((v - _stretch.value).abs() > 0.004 || (v == 0 && _stretch.value != 0)) {
      _stretch.value = v;
    }
  }

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletProvider>();
    if (!wallet.isLoaded) wallet.load();
    _scroll.addListener(_onScroll);
  }

  void _open(WalletCard card) {
    Navigator.of(context).push(FadeRoute(
      builder: (_) => CardDetailScreen(cardId: card.id),
    ));
  }

  Future<void> _delete(WalletCard card) async {
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final removed = await wallet.remove(card.id);
    if (removed == null) return;
    final (gone, index) = removed;
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 7),
      content: Row(children: [
        const Icon(Icons.delete_outline_rounded,
            color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('•• ${gone.last4} removed')),
      ]),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          Haptics.tap();
          wallet.restore(gone, index);
        },
      ),
    ));
    final reason = await controller.closed;
    if (reason != SnackBarClosedReason.action) wallet.purgeAssets(gone);
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: AppPrefs.name.value);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What should we call you?', style: AppText.title),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: AppText.title.copyWith(fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              const SizedBox(height: 18),
              GradientButton(
                  label: 'Save',
                  onPressed: () => Navigator.pop(context, controller.text)),
            ]),
      ),
    );
    if (name != null) AppPrefs.setName(name);
  }

  Future<void> _showMenu(int count) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (count > 1)
            _MenuRow(
              icon: Icons.swap_vert_rounded,
              title: 'Arrange & pin',
              subtitle: 'Reorder cards, keep favourites on top',
              onTap: () => Navigator.pop(context, 'arrange'),
            ),
          _MenuRow(
            icon: Icons.lock_rounded,
            title: 'Back up cards',
            subtitle: 'Export an encrypted, password-protected file',
            onTap: () => Navigator.pop(context, 'export'),
          ),
          _MenuRow(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Restore from backup',
            subtitle: 'Import cards from a backup file',
            onTap: () => Navigator.pop(context, 'import'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'arrange':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ArrangeScreen()));
      case 'export':
        showExportSheet(context);
      case 'import':
        startImport(context);
    }
  }

  /// Opens the peek strip towards a full card as the list is overstretched.
  static double _fan(double base, double stretch) =>
      base + (0.62 - base) * Curves.easeOut.transform(stretch);

  static String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Up late';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final cards = wallet.cards;
    final width = MediaQuery.sizeOf(context).width - 40;
    final stagger = _firstPaint && wallet.isLoaded;
    if (stagger) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _firstPaint = false);
    }

    return Scaffold(
      body: Stack(children: [
        const Positioned(
            top: -140,
            left: -120,
            child: GlowOrb(color: AppColors.iris, size: 380, opacity: 0.22)),
        const Positioned(
            top: -60,
            right: -160,
            child: GlowOrb(color: AppColors.pink, size: 360, opacity: 0.14)),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _Header(
                    greeting: _timeGreeting(),
                    onEditName: _editName,
                    onMenu: () => _showMenu(cards.length),
                  ),
                ),
              ),
              if (!wallet.isLoaded)
                const SliverFillRemaining(child: SizedBox.shrink())
              else if (cards.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: WalletEmptyState(
                          onAdd: () => showAddCardSheet(context)),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Entrance(
                      child: _SummaryTile(
                        total: wallet.totalLimit,
                        count: cards.length,
                        onAdd: () => showAddCardSheet(context),
                      ),
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 14),
                  sliver: SliverToBoxAdapter(child: SectionLabel('Your cards')),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: _stretch,
                  builder: (context, stretch, _) => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: cards.length,
                      itemBuilder: (context, i) {
                        final card = cards[i];
                        final isLast = i == cards.length - 1;
                        return Entrance(
                          key: ValueKey('in-${card.id}'),
                          delay: Duration(
                              milliseconds: stagger ? 120 + i * 70 : 0),
                          offset: 70,
                          child: _StackedCard(
                            key: ValueKey(card.id),
                            card: card,
                            logoAsset: wallet.logoAssetFor(card.bank),
                            width: width,
                            peek: isLast
                                ? 1.0
                                : _fan(
                                    cards.length == 2 ? 0.40 : 0.30, stretch),
                            onTap: () => _open(card),
                            onDelete: () => _delete(card),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, 28, 20, 40 + MediaQuery.paddingOf(context).bottom),
                    child: const Text(
                      'tap to open · swipe left to remove',
                      textAlign: TextAlign.center,
                      style: AppText.mono,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.onEditName,
    required this.onMenu,
  });

  final String greeting;
  final VoidCallback onEditName;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: GestureDetector(
          onTap: onEditName,
          behavior: HitTestBehavior.opaque,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting.toUpperCase(), style: AppText.label),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: AppPrefs.name,
              builder: (context, name, _) => Text(
                'Hey ${name.isEmpty ? 'there' : name.split(' ').first}',
                style: AppText.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
      GlassIconButton(
          icon: Icons.more_horiz_rounded, tooltip: 'More', onTap: onMenu),
    ]);
  }
}

/// One compact row: total limit (or card count) on the left, add on the right.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile(
      {required this.total, required this.count, required this.onAdd});

  final double total;
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cardsText = '$count ${count == 1 ? 'card' : 'cards'}';
    final hasLimit = total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hasLimit ? 'TOTAL LIMIT' : 'YOUR WALLET',
                style: AppText.label),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: hasLimit ? total : count.toDouble()),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: hasLimit
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                            Text('₹',
                                style: AppText.label.copyWith(
                                    fontSize: 20,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0)),
                            const SizedBox(width: 4),
                            Text(formatInr(v).substring(1),
                                style: AppText.display.copyWith(fontSize: 32)),
                          ])
                    : Text(cardsText.toUpperCase(),
                        style: AppText.display.copyWith(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.lock_rounded, size: 11, color: AppColors.lime),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  hasLimit ? '$cardsText · on-device' : 'on-device · encrypted',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono.copyWith(fontSize: 11.5),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Add card',
          child: Pressable(
            onTap: onAdd,
            scale: 0.9,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.add_rounded, color: AppColors.ink, size: 28),
            ),
          ),
        ),
      ]),
    );
  }
}

/// One card in the wallet stack: only its top strip is visible (the next card
/// overlaps the rest). Swipe left past the threshold to delete.
class _StackedCard extends StatefulWidget {
  const _StackedCard({
    super.key,
    required this.card,
    required this.logoAsset,
    required this.width,
    required this.peek,
    required this.onTap,
    required this.onDelete,
  });

  final WalletCard card;
  final String? logoAsset;
  final double width;
  final double peek;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_StackedCard> createState() => _StackedCardState();
}

class _StackedCardState extends State<_StackedCard> {
  final _progress = ValueNotifier<double>(0);
  bool _armed = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      // Delete affordance revealed behind the sliding card.
      Positioned.fill(
        child: ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, p, _) {
            if (p <= 0) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color:
                    AppColors.danger.withValues(alpha: (p * 2.5).clamp(0, 1)),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 26),
              child: Transform.scale(
                scale: _armed ? 1.25 : 0.8 + p,
                child: const Icon(Icons.delete_rounded,
                    color: Colors.white, size: 26),
              ),
            );
          },
        ),
      ),
      Dismissible(
        key: ValueKey('swipe-${widget.card.id}'),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: 0.4},
        movementDuration: const Duration(milliseconds: 260),
        resizeDuration: const Duration(milliseconds: 280),
        onUpdate: (d) {
          _progress.value = d.progress;
          if (d.reached != _armed) {
            _armed = d.reached;
            if (_armed) Haptics.warn();
          }
        },
        onDismissed: (_) => widget.onDelete(),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: widget.peek,
          child: SizedBox(
            width: widget.width,
            child: Pressable(
              onTap: widget.onTap,
              scale: 0.98,
              child: Hero(
                tag: 'card-${widget.card.id}',
                flightShuttleBuilder: cardFlightShuttle,
                child: WalletCardFace(
                  data: CardFaceData.fromCard(widget.card,
                      logoAsset: widget.logoAsset),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.mono.copyWith(fontSize: 11.5)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ]),
      ),
    );
  }
}
