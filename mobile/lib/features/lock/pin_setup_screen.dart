import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'app_lock_controller.dart';
import 'app_lock_platform.dart';
import 'pin_hasher.dart';
import 'pin_pad.dart';

/// Yeni PIN belirleme: önce 4-8 rakamlı PIN girilir ("Devam"), sonra aynısı
/// tekrar girilir. Eşleşirse ekran PIN'i döndürerek kapanır; eşleşmezse baştan.
/// PIN'i kaydetmek çağıranın işidir.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _entered = '';
  bool _confirming = false;
  bool _mismatch = false;

  void _digit(String digit) {
    final limit = _confirming ? _first.length : maxPinLength;
    if (_entered.length >= limit) return;
    setState(() {
      _entered += digit;
      _mismatch = false;
    });
    if (_confirming && _entered.length == _first.length) _checkConfirm();
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _mismatch = false;
    });
  }

  void _next() {
    if (!isValidPin(_entered)) return;
    setState(() {
      _first = _entered;
      _entered = '';
      _confirming = true;
    });
  }

  void _checkConfirm() {
    if (_entered == _first) {
      Navigator.pop(context, _first);
      return;
    }
    setState(() {
      _first = '';
      _entered = '';
      _confirming = false;
      _mismatch = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lockSetupTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _confirming ? l10n.lockSetupConfirm : l10n.lockSetupEnter,
                  key: const Key('pin_kurulum_baslik'),
                  style: text.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PinDots(
                  filled: _entered.length,
                  slots: _confirming ? _first.length : maxPinLength,
                  error: _mismatch,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 24,
                  child: _mismatch
                      ? Text(l10n.lockSetupMismatch, key: const Key('pin_uyusmadi'), style: text.bodyMedium?.copyWith(color: scheme.error))
                      : null,
                ),
                const SizedBox(height: 12),
                PinPad(backspaceLabel: l10n.lockBackspace, onDigit: _digit, onBackspace: _backspace),
                const SizedBox(height: 16),
                if (!_confirming)
                  FilledButton(
                    key: const Key('pin_devam'),
                    onPressed: isValidPin(_entered) ? _next : null,
                    child: Text(l10n.commonContinue),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mevcut PIN'i soran pencere (kilidi kapatırken, PIN değiştirirken). PIN
/// doğruysa onu döndürür; vazgeçilirse null. Yanlış denemeler kilit ekranındakiyle
/// aynı sayaca işler.
Future<String?> confirmCurrentPin(BuildContext context) {
  return showDialog<String>(context: context, builder: (_) => const _ConfirmPinDialog());
}

class _ConfirmPinDialog extends ConsumerStatefulWidget {
  const _ConfirmPinDialog();

  @override
  ConsumerState<_ConfirmPinDialog> createState() => _ConfirmPinDialogState();
}

class _ConfirmPinDialogState extends ConsumerState<_ConfirmPinDialog> {
  String _entered = '';
  String? _error;
  bool _checking = false;

  Future<void> _digit(String digit) async {
    final lock = ref.read(appLockProvider);
    if (_checking || _entered.length >= lock.pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length < lock.pinLength) return;

    _checking = true;
    final result = await ref.read(appLockProvider.notifier).checkPin(_entered, unlock: false);
    _checking = false;
    if (!mounted) return;
    final l10n = context.l10n;
    switch (result) {
      case PinResult.ok:
        Navigator.pop(context, _entered);
      case PinResult.wrong:
        setState(() {
          _entered = '';
          _error = l10n.lockWrongPin;
        });
      case PinResult.blocked:
        final wait = ref.read(appLockProvider).blockedUntil!.difference(ref.read(appLockClockProvider)());
        setState(() {
          _entered = '';
          _error = l10n.lockBlocked(formatWait(l10n, wait));
        });
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lock = ref.watch(appLockProvider);
    return AlertDialog(
      title: Text(l10n.lockConfirmCurrent),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinDots(filled: _entered.length, slots: lock.pinLength, error: _error != null),
            SizedBox(
              height: 28,
              child: _error == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, key: const Key('pin_dogrula_hata'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
            ),
            const SizedBox(height: 8),
            PinPad(backspaceLabel: l10n.lockBackspace, onDigit: _digit, onBackspace: _backspace),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('pin_dogrula_vazgec'), onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
      ],
    );
  }
}
