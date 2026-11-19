// Ayarlar ekranı: uygulama kilidi ve "tüm verimi sil". Profil, KVKK onayı ve
// yedek sonraki adımlarda buraya eklenir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/turkish_text.dart' show upperTr;
import '../../l10n/l10n.dart';
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
            // Bölümler taslaktaki sırayla (Ayarlar panosu): Güvenlik (kilit,
            // yedekleme), Otomatik veri (adım takibi), Uygulama (profil, günlük
            // alanlar, bildirimler). "Tüm verimi sil" taslakta yok ama işlevi
            // korunur: en altta "Veriler" bölümünde. Yedekten geri yükleme artık
            // Yedekleme ekranındaki düğmeden açılır; Boy ve kilo Sağlık
            // sekmesinden.
            _header(text, l10n.settingsGroupSecurity, first: true),
            const AppLockSettingsCard(),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: _SettingsRow(
                rowKey: const Key('ayar_yedek_al'),
                title: l10n.settingsBackupRowTitle,
                hint: l10n.settingsBackupRowHint,
                route: '/backup',
              ),
            ),
            _header(text, l10n.settingsGroupAuto),
            const StepSettingsCard(),
            _header(text, l10n.settingsGroupApp),
            const Card(
              margin: EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  _ProfileRow(),
                  Divider(height: 1),
                  _SettingsRowFromL10n(
                    rowKey: Key('ayar_gunluk_alanlar'),
                    kind: _RowKind.fields,
                    route: '/daily-fields',
                  ),
                  Divider(height: 1),
                  _SettingsRowFromL10n(
                    rowKey: Key('ayar_bildirimler'),
                    kind: _RowKind.notifications,
                    route: '/recurring',
                  ),
                ],
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
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.settingsFooter,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Taslaktaki ayar satırı: başlık, altında açıklama, sağda ok. Simgesiz.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.rowKey,
    required this.title,
    required this.hint,
    required this.route,
  });

  final Key rowKey;
  final String title;
  final String hint;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: rowKey,
      minVerticalPadding: 10,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(hint),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(route),
    );
  }
}

enum _RowKind { fields, notifications }

/// Çeviriden başlık/açıklama alan `_SettingsRow` (const listede kullanılabilsin diye).
class _SettingsRowFromL10n extends StatelessWidget {
  const _SettingsRowFromL10n({required this.rowKey, required this.kind, required this.route});

  final Key rowKey;
  final _RowKind kind;
  final String route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, hint) = switch (kind) {
      _RowKind.fields => (l10n.settingsFieldsRowTitle, l10n.settingsFieldsRowHint),
      _RowKind.notifications => (
          l10n.settingsNotificationsRowTitle,
          l10n.settingsNotificationsRowHint,
        ),
    };
    return _SettingsRow(rowKey: rowKey, title: title, hint: hint, route: route);
  }
}

/// "Profil ve sağlık kartı" satırı; profilde ad varsa açıklama yerine ad görünür.
/// Profil okunamazsa satır yine açılır, açıklama görünür.
class _ProfileRow extends ConsumerWidget {
  const _ProfileRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider).valueOrNull;
    final name = profile == null ? '' : '${profile.firstName} ${profile.lastName}'.trim();
    return _SettingsRow(
      rowKey: const Key('ayar_profil'),
      title: l10n.settingsProfileRowTitle,
      hint: name.isEmpty ? l10n.settingsProfileRowHint : name,
      route: '/profile',
    );
  }
}
