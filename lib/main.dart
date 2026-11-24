import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:pocket_cards/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

import 'CreditCardScreen.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_services.dart';
import 'theme/app_theme.dart';
import 'theme/card_skins.dart';
import 'widgets/ui_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.ink,
  ));
  await Future.wait([AppPrefs.init(), CardSkins.init()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CardProvider()),
        ChangeNotifierProvider(create: (context) => WalletProvider()),
      ],
      child: MyApp(showOnboarding: !AppPrefs.onboarded),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Cards',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: showOnboarding
          ? Builder(
              builder: (context) => OnboardingScreen(
                onDone: () => Navigator.of(context).pushReplacement(
                  FadeRoute(builder: (_) => const BiometricAuthScreen()),
                ),
              ),
            )
          : const BiometricAuthScreen(),
    );
  }
}

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticateUser());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _enter() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      FadeRoute(builder: (context) => const CreditCardScreen()),
    );
  }

  Future<void> _authenticateUser() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final bool isBiometricAvailable = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!isBiometricAvailable && !isDeviceSupported) {
        // If authentication is not available, proceed to the next screen without it.
        _enter();
        return;
      }

      final bool authenticated = await auth.authenticate(
        localizedReason: 'Unlock Pocket Cards',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow system PIN as well
        ),
      );

      if (authenticated) {
        Haptics.copy();
        _enter();
      } else {
        Haptics.warn();
        if (mounted) setState(() => _failed = true);
      }
    } catch (e) {
      // If there's an error, log it but proceed without authentication.
      debugPrint('Authentication error: ${e.toString()}');
      _enter();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned(top: -160, left: -120, child: GlowOrb(color: AppColors.iris, size: 460, opacity: 0.25)),
        const Positioned(bottom: -200, right: -160, child: GlowOrb(color: AppColors.pink, size: 480, opacity: 0.16)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const Spacer(flex: 3),
              GestureDetector(
                onTap: _authenticateUser,
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      return Stack(alignment: Alignment.center, children: [
                        // Expanding ripples
                        for (var k = 0; k < 2; k++)
                          Builder(builder: (context) {
                            final v = (_pulse.value + k * 0.5) % 1.0;
                            return Opacity(
                              opacity: (1 - v) * 0.5,
                              child: Container(
                                width: 110 + v * 110,
                                height: 110 + v * 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (_failed ? AppColors.danger : AppColors.iris),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            );
                          }),
                        Transform.scale(
                          scale: 1 + math.sin(_pulse.value * 2 * math.pi) * 0.025,
                          child: AnimatedContainer(
                            duration: AppMotion.medium,
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _failed
                                  ? const LinearGradient(colors: [AppColors.danger, AppColors.pink])
                                  : AppColors.brandGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: (_failed ? AppColors.danger : AppColors.violet)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.fingerprint_rounded, size: 56, color: AppColors.ink),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('pocket', style: AppText.display.copyWith(fontSize: 40)),
                Text('.', style: AppText.display.copyWith(fontSize: 40, color: AppColors.iris)),
              ]),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: Text(
                  _failed ? "That didn't work. Try again." : 'Your cards are locked',
                  key: ValueKey(_failed),
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    color: _failed ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(flex: 4),
              GradientButton(
                label: _busy ? 'Waiting…' : 'Tap to unlock',
                icon: Icons.lock_open_rounded,
                onPressed: _authenticateUser,
              ),
              const SizedBox(height: 14),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.wifi_off_rounded, size: 13, color: AppColors.textTertiary),
                SizedBox(width: 6),
                Text('Offline · on-device · encrypted',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ]),
    );
  }
}
