import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primary200 : AppColors.primary600;
    // Taslaktaki "Kilit" panosu: üstte 64 px yuvarlak kilit simgesi, başlık, alt
    // yazı, noktalar, tuş takımı ve altta "Parmak iziyle aç" metin düğmesi.
    return Scaffold(
      key: const Key('kilit_ekrani'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 72, 28, 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primary900 : AppColors.primary50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, size: 30, color: accent),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.lockTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  key: const Key('kilit_mesaj'),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: (_wrong || blocked)
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                PinDots(filled: _entered.length, slots: lock.pinLength, error: _wrong || blocked),
                const SizedBox(height: 28),
                PinPad(
                  enabled: !blocked,
                  backspaceLabel: l10n.lockBackspace,
                  onDigit: _digit,
                  onBackspace: _backspace,
                ),
                if (lock.biometric)
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: TextButton.icon(
                      key: const Key('kilit_biyometrik'),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: _biometric,
                      icon: Icon(Icons.fingerprint, size: 22, color: accent),
                      label: Text(
                        l10n.lockBiometricButton,
                        style: TextStyle(
                            color: accent, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
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
