import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'app_lock_controller.dart';
import 'app_lock_platform.dart';
import 'pin_pad.dart';
import 'recovery_screen.dart';

/// Kilit ekranı: uygulamanın üstünü tamamen kaplar. Doğru PIN (ya da parmak izi)
/// girilene kadar altındaki ekranlara erişilemez. PIN unutulduysa "PIN'imi
/// unuttum" kurtarma kodu ekranına götürür.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  bool _wrong = false;
  bool _checking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Kilit ekranı açılır açılmaz biyometrik pencere bir kez önerilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(appLockProvider).biometric) _biometric();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _biometric() async {
    await ref.read(appLockProvider.notifier).authenticateBiometric(context.l10n.lockBiometricReason);
  }

  Future<void> _digit(String digit) async {
    final lock = ref.read(appLockProvider);
    if (_checking || _entered.length >= lock.pinLength || lock.isBlocked(ref.read(appLockClockProvider)())) return;
    setState(() {
      _entered += digit;
      _wrong = false;
    });
    if (_entered.length < lock.pinLength) return;

    _checking = true;
    final result = await ref.read(appLockProvider.notifier).checkPin(_entered);
    _checking = false;
    if (!mounted) return;
    setState(() {
      _entered = '';
      _wrong = result != PinResult.ok;
    });
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _wrong = false;
    });
  }

  void _forgot() {
    setState(() => _entered = '');
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RecoveryScreen()));
  }

  /// Giriş kapalıysa kalan süreyi saniye saniye güncellemek için sayaç kurar.
  void _syncTicker(bool blocked) {
    if (blocked && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!blocked && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final now = ref.read(appLockClockProvider)();
    final blocked = lock.isBlocked(now);
    _syncTicker(blocked);
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    final String message;
    if (blocked) {
      message = l10n.lockBlocked(formatWait(l10n, lock.blockedUntil!.difference(now)));
    } else if (_wrong) {
      message = l10n.lockWrongPin;
    } else {
      message = l10n.lockEnterPin;
    }

    return Scaffold(
      key: const Key('kilit_ekrani'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(l10n.lockTitle, style: text.titleLarge),
                const SizedBox(height: 24),
                PinDots(filled: _entered.length, slots: lock.pinLength, error: _wrong || blocked),
                const SizedBox(height: 12),
                Text(
                  message,
                  key: const Key('kilit_mesaj'),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: (_wrong || blocked) ? Theme.of(context).colorScheme.error : null),
                ),
                const SizedBox(height: 24),
                PinPad(
                  enabled: !blocked,
                  backspaceLabel: l10n.lockBackspace,
                  onDigit: _digit,
                  onBackspace: _backspace,
                  bottomLeft: lock.biometric
                      ? IconButton(
                          key: const Key('kilit_biyometrik'),
                          onPressed: _biometric,
                          icon: Semantics(label: l10n.lockBiometricButton, child: const Icon(Icons.fingerprint, size: 32)),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('kilit_unuttum'),
                  onPressed: _forgot,
                  child: Text(l10n.lockForgotPin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
