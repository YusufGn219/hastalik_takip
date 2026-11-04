// GEÇİCİ: ayarlar ekranı gelene kadar kilidi ana ekrandan açıp kapatmak ve
// telefonda denemek için küçük kart. Ayarlar ekranı yazılınca oraya taşınır
// (PIN değiştirme ve kurtarma kodunu yenileme de orada olacak).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'app_lock_controller.dart';
import 'app_lock_platform.dart';
import 'app_lock_store.dart';
import 'lock_flows.dart';
import 'pin_setup_screen.dart';

final _biometricAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(biometricAuthenticatorProvider).isAvailable(),
);

class AppLockSettingsCard extends ConsumerWidget {
  const AppLockSettingsCard({super.key});

  String _timeoutLabel(BuildContext context, int seconds) {
    final l10n = context.l10n;
    if (seconds == 0) return l10n.lockTimeoutNow;
    if (seconds < 60) return l10n.lockTimeoutSeconds(seconds);
    return l10n.lockTimeoutMinutes(seconds ~/ 60);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final lock = ref.read(appLockProvider.notifier);
    if (on) {
      await runEnableLockFlow(context, ref);
      return;
    }
    final pin = await confirmCurrentPin(context);
    if (pin != null) await lock.disable(pin);
  }

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool on) async {
    final lock = ref.read(appLockProvider.notifier);
    if (on) {
      // Açmadan önce doğrulama istenir: parmak izi gerçekten çalışıyor mu.
      final ok = await lock.authenticateBiometric(context.l10n.lockBiometricReason, unlock: false);
      if (!ok) return;
    }
    await lock.setBiometric(on);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lock = ref.watch(appLockProvider);
    final bioAvailable = ref.watch(_biometricAvailableProvider).valueOrNull ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('ayar_kilit'),
            secondary: const Icon(Icons.lock_outline),
            title: Text(l10n.lockSettingsTitle),
            subtitle: Text(lock.enabled ? l10n.lockSettingsOnHint : l10n.lockSettingsOffHint),
            value: lock.enabled,
            onChanged: (on) => _toggle(context, ref, on),
          ),
          if (lock.enabled) ...[
            if (bioAvailable)
              SwitchListTile(
                key: const Key('ayar_kilit_biyometrik'),
                secondary: const Icon(Icons.fingerprint),
                title: Text(l10n.lockSettingsBiometric),
                value: lock.biometric,
                onChanged: (on) => _toggleBiometric(context, ref, on),
              ),
            ListTile(
              key: const Key('ayar_kilit_sure'),
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.lockSettingsTimeout),
              trailing: DropdownButton<int>(
                value: lock.timeoutSeconds,
                onChanged: (v) {
                  if (v != null) ref.read(appLockProvider.notifier).setTimeout(v);
                },
                items: [
                  for (final s in AppLockStore.timeoutOptions)
                    DropdownMenuItem(value: s, child: Text(_timeoutLabel(context, s))),
                ],
              ),
            ),
            ListTile(
              key: const Key('ayar_kilit_simdi'),
              leading: const Icon(Icons.lock_clock),
              title: Text(l10n.lockSettingsLockNow),
              onTap: () => ref.read(appLockProvider.notifier).lockNow(),
            ),
          ],
        ],
      ),
    );
  }
}
