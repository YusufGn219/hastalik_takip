import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'app_lock_controller.dart';
import 'app_lock_platform.dart';
import 'pin_pad.dart';
import 'pin_setup_screen.dart';
import 'recovery_code.dart';
import 'recovery_code_screen.dart';

/// "PIN'imi unuttum": kurtarma kodu girilir, doğruysa yeni PIN belirlenir, yeni
/// kurtarma kodu gösterilir ve kilit açılır. Kod da kayıpsa son çare "tüm veriyi
/// sil ve baştan başla"dır (uyarı ve onayla).
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = context.l10n;
    final code = normalizeRecoveryCode(_controller.text);
    if (!isValidRecoveryCode(code)) {
      setState(() => _error = l10n.recoveryCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final lock = ref.read(appLockProvider.notifier);
    final checked = await lock.checkRecoveryCode(code);
    if (!mounted) return;
    switch (checked) {
      case PinResult.wrong:
        setState(() {
          _busy = false;
          _error = l10n.recoveryWrongCode;
        });
        return;
      case PinResult.blocked:
        final until = ref.read(appLockProvider).blockedUntil;
        final wait = until == null ? Duration.zero : until.difference(ref.read(appLockClockProvider)());
        setState(() {
          _busy = false;
          _error = l10n.recoveryBlocked(formatWait(l10n, wait));
        });
        return;
      case PinResult.ok:
        break;
    }

    final pin = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    if (!mounted) return;
    if (pin == null) {
      setState(() => _busy = false);
      return;
    }

    // Kilit, yeni kod gösterilene kadar açılmaz (kilit ekranı kodla birlikte kaybolmasın).
    final out = await lock.recoverWithCode(code, pin, unlock: false);
    if (!mounted) return;
    if (out.result != PinResult.ok) {
      setState(() {
        _busy = false;
        _error = l10n.recoveryWrongCode;
      });
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => RecoveryCodeScreen(code: out.newCode!)));
    lock.finishRecovery();
  }

  Future<void> _wipe() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wipeTitle),
        content: Text(l10n.wipeBody),
        actions: [
          TextButton(
            key: const Key('silme_vazgec'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('silme_onay'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.wipeConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Silme bitince kilit kalkar ve bu ekran ağaçtan kalkar; önce gerekenleri al.
    final lock = ref.read(appLockProvider.notifier);
    final restart = ref.read(appRestartProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await lock.wipeAllData();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.wipeFailed)));
      return;
    }
    await restart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.recoveryEnterCode, style: text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('kurtarma_alan'),
                  controller: _controller,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')), LengthLimitingTextInputFormatter(20)],
                  decoration: InputDecoration(labelText: l10n.recoveryCodeField, hintText: 'XXXX-XXXX-XXXX'),
                  onSubmitted: (_) => _submit(),
                ),
                SizedBox(
                  height: 32,
                  child: _error == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, key: const Key('kurtarma_hata'), style: text.bodyMedium?.copyWith(color: scheme.error)),
                        ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('kurtarma_devam'),
                  onPressed: _busy ? null : _submit,
                  child: Text(l10n.commonContinue),
                ),
                const SizedBox(height: 24),
                TextButton(
                  key: const Key('kurtarma_kayip'),
                  onPressed: _busy ? null : _wipe,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: Text(l10n.recoveryLostBoth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
