import 'models/wallet_card.dart';

/// Store-screenshot mode. Off unless built with `--dart-define=DEMO=true`.
/// Skips onboarding and the lock, and shows fictional sample cards held in
/// memory only (nothing is read from or written to secure storage).
const bool kDemoMode = bool.fromEnvironment('DEMO');

const String kDemoName = 'Aarav';

/// Fictional banks and numbers (prefix 9 => no card-network mark is drawn).
const List<WalletCard> kDemoCards = [
  WalletCard(
    id: 'demo-1',
    number: '9405118822104821',
    holder: 'Aarav Mehta',
    expiry: '08/29',
    cvv: '317',
    bank: 'Nova Bank',
    skinId: 'grad:aurora',
    limit: 300000,
    pinned: true,
    logoStyle: LogoStyle.text,
  ),
  WalletCard(
    id: 'demo-2',
    number: '9122640017737730',
    holder: 'Aarav Mehta',
    expiry: '03/28',
    cvv: '582',
    bank: 'Orbit',
    skinId: 'grad:sunset',
    limit: 150000,
    logoStyle: LogoStyle.text,
  ),
  WalletCard(
    id: 'demo-3',
    number: '9877120056410912',
    holder: 'Aarav Mehta',
    expiry: '11/30',
    cvv: '904',
    bank: 'Lumen',
    skinId: 'grad:candy',
    limit: 200000,
    logoStyle: LogoStyle.text,
  ),
  WalletCard(
    id: 'demo-4',
    number: '9300448812905518',
    holder: 'Aarav Mehta',
    expiry: '06/27',
    cvv: '146',
    bank: 'Fern',
    skinId: 'grad:mint',
    limit: 0,
    logoStyle: LogoStyle.text,
  ),
  WalletCard(
    id: 'demo-5',
    number: '9711093366202044',
    holder: 'Aarav Mehta',
    expiry: '01/31',
    cvv: '663',
    bank: 'Monolith',
    skinId: 'grad:mono',
    limit: 100000,
    logoStyle: LogoStyle.text,
  ),
];
