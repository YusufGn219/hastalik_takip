// Ayarlar ekranı: uygulama kilidi ve "tüm verimi sil". Profil, KVKK onayı ve
// yedek sonraki adımlarda buraya eklenir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/turkish_text.dart' show upperTr;
import '../../l10n/l10n.dart';
import '../profile/profile_avatar.dart';
import '../lock/app_lock_controller.dart';
import '../lock/app_lock_platform.dart';
import '../lock/lock_settings_card.dart';
import '../lock/pin_setup_screen.dart';
import '../steps/step_settings_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Tüm veriyi siler. Kilit açıksa önce PIN istenir (telefon başkasının eline
  /// geçtiyse tek dokunuşla silinmesin); sonra uyarı penceresi. Başarılı olunca
  /// uygulama baştan kurulur (tanıtım yeniden çıkar), başarısız olursa veri yerinde
  /// kalır ve hata gösterilir.
  Future<void> _wipeAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (ref.read(appLockProvider).enabled) {
      final pin = await confirmCurrentPin(context);
      if (pin == null || !context.mounted) return;
    }
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
    if (ok != true || !context.mounted) return;

    // Silme bitince uygulama baştan kurulur ve bu ekran ağaçtan kalkar; önce
    // gerekenleri al.
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

  /// Bölüm başlığı: küçük, büyük harfli (taslaktaki gibi).
  Widget _header(TextTheme text, String label, {bool first = false}) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 16, bottom: 8, left: 2),
        child: Text(
          upperTr(label),
          style: text.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bölümler taslaktaki sırayla: Güvenlik (kilit + yedek), Otomatik veri,
            // Uygulama (profil, boy-kilo), Veri (tümünü sil).
            _header(text, l10n.settingsGroupSecurity, first: true),
            const AppLockSettingsCard(),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                key: const Key('ayar_yedek_al'),
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(l10n.settingsBackupExportTitle),
                subtitle: Text(l10n.settingsBackupExportHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/backup'),
              ),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                key: const Key('ayar_yedek_geri'),
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(l10n.settingsRestoreTitle),
                subtitle: Text(l10n.settingsRestoreHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/restore'),
              ),
            ),
            _header(text, l10n.settingsGroupAuto),
            const StepSettingsCard(),
            _header(text, l10n.settingsGroupApp),
            const _ProfileCard(),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                key: const Key('ayar_boy_kilo'),
                leading: const Icon(Icons.monitor_weight_outlined),
                title: Text(l10n.settingsBodyTitle),
                subtitle: Text(l10n.settingsBodyHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/body'),
              ),
            ),
            _header(text, l10n.settingsDataSection),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                key: const Key('ayar_tum_veri_sil'),
                leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
                title: Text(
                  l10n.settingsWipeTitle,
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: Text(l10n.settingsWipeHint),
                onTap: () => _wipeAll(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ayarların en üstündeki profil kartı: fotoğraf, ad ve soyad; dokununca Profil
/// ekranı açılır. Profil okunamazsa kart yine açılır, ad yerine ipucu görünür.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider).valueOrNull;
    final name = profile == null ? '' : '${profile.firstName} ${profile.lastName}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        key: const Key('ayar_profil'),
        leading: ProfileAvatar(photo: profile?.photo, radius: 24),
        title: Text(name.isEmpty ? l10n.settingsProfileTitle : name),
        subtitle: name.isEmpty ? Text(l10n.settingsProfileEmpty) : Text(l10n.settingsProfileTitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed('/profile'),
      ),
    );
  }
}
