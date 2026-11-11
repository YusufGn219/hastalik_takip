// Ayarlar'daki "Adım takibi" kartı: anahtar (varsayılan kapalı) ve izin durumu.
// Açarken fiziksel aktivite izni istenir; izin verilmezse anahtar kapalı kalır.
// Kullanıcı açtıktan sonra izni telefon ayarlarından geri alırsa kartta uyarı ve
// "Ayarları aç" düğmesi çıkar; ayarlardan dönünce durum yeniden okunur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/step_control.dart';
import '../../l10n/l10n.dart';

class StepSettingsCard extends ConsumerStatefulWidget {
  const StepSettingsCard({super.key});

  @override
  ConsumerState<StepSettingsCard> createState() => _StepSettingsCardState();
}

class _StepSettingsCardState extends ConsumerState<StepSettingsCard>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Telefon ayarlarından dönüşte izin durumu değişmiş olabilir.
    if (state == AppLifecycleState.resumed) ref.invalidate(stepControlStateProvider);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    final l10n = context.l10n;
    final control = ref.read(stepControlProvider);
    setState(() => _busy = true);
    try {
      if (on) {
        switch (await control.enable()) {
          case StepEnableResult.enabled:
            break;
          case StepEnableResult.denied:
            _say(l10n.settingsStepsDenied);
          case StepEnableResult.permanentlyDenied:
            _say(l10n.settingsStepsDeniedForever);
            await control.openPermissionSettings();
          case StepEnableResult.failed:
            _say(l10n.settingsStepsFailed);
        }
      } else {
        try {
          await control.disable();
        } catch (_) {
          _say(l10n.settingsStepsOffFailed);
        }
      }
    } finally {
      ref.invalidate(stepControlStateProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(stepControlStateProvider).valueOrNull;
    final enabled = state?.enabled ?? false;
    final lost = state?.permissionLost ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('ayar_adim_takibi'),
            secondary: const Icon(Icons.directions_walk_outlined),
            title: Text(l10n.settingsStepsTitle),
            subtitle: Text(l10n.settingsStepsHint),
            value: enabled,
            onChanged: _busy || state == null ? null : _toggle,
          ),
          if (lost)
            ListTile(
              key: const Key('adim_izin_uyari'),
              leading: Icon(Icons.warning_amber_outlined, color: scheme.error),
              title: Text(
                l10n.settingsStepsPermissionLost,
                style: TextStyle(color: scheme.error),
              ),
              trailing: TextButton(
                key: const Key('adim_izin_ayarlari'),
                onPressed: () => ref.read(stepControlProvider).openPermissionSettings(),
                child: Text(l10n.settingsStepsOpenSettings),
              ),
            ),
        ],
      ),
    );
  }
}
