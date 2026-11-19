// "Yedekleme" ekranı (taslaktaki "Yedek" panosu): parolayı iki kez alır, yedeği
// şifreleyip kullanıcının seçtiği yere kaydettirir; "Yedekten geri yükle" düğmesi
// geri yükleme ekranını açar. Parola hiçbir yere kaydedilmez ve günlüğe yazılmaz.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_service.dart';
import '../../l10n/l10n.dart';
import 'backup_exporter.dart';
import 'backup_platform.dart';

enum _Status { idle, working, done, cancelled, failed }

class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({super.key});

  @override
  ConsumerState<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  _Status _status = _Status.idle;
  String? _passError;
  String? _confirmError;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Alanları denetler; geçerliyse parolayı döndürür.
  String? _validate() {
    final l10n = context.l10n;
    final pass = _pass.text;
    String? passError;
    String? confirmError;
    if (pass.runes.length < BackupService.minPassphraseLength) {
      passError = l10n.backupTooShort(BackupService.minPassphraseLength);
    } else if (_confirm.text != pass) {
      confirmError = l10n.backupMismatch;
    }
    setState(() {
      _passError = passError;
      _confirmError = confirmError;
    });
    return passError == null && confirmError == null ? pass : null;
  }

  Future<void> _export() async {
    final pass = _validate();
    if (pass == null || _status == _Status.working) return;
    FocusScope.of(context).unfocus();
    setState(() => _status = _Status.working);

    final exporter = ref.read(backupExporterProvider);
    _Status next;
    try {
      final result = await exporter.run(pass);
      next = result == BackupExportResult.saved ? _Status.done : _Status.cancelled;
    } catch (e) {
      // Parola ve içerik günlüğe yazılmaz; yalnız hata türü.
      debugPrint('Yedek alınamadı: ${e.runtimeType}');
      next = _Status.failed;
    }
    if (!mounted) return;
    if (next == _Status.done) {
      _pass.clear();
      _confirm.clear();
    }
    setState(() => _status = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final working = _status == _Status.working;

    final toggle = IconButton(
      key: const Key('yedek_goster'),
      tooltip: _show ? l10n.backupHidePassphrase : l10n.backupShowPassphrase,
      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _show = !_show),
    );

    final Widget? result = switch (_status) {
      _Status.done => Text(l10n.backupDone,
          key: const Key('yedek_sonuc'), style: TextStyle(color: scheme.primary)),
      _Status.cancelled => Text(l10n.backupCancelled, key: const Key('yedek_sonuc')),
      _Status.failed => Text(l10n.backupFailed,
          key: const Key('yedek_sonuc'), style: TextStyle(color: scheme.error)),
      _ => null,
    };

    // Taslaktaki sarı uyarı: açık temada krem zemin, koyu temada şeffaf sarı.
    final amberBg = isDark ? const Color(0x29EF9F27) : const Color(0xFFFAEEDA);
    final amberFg = isDark ? const Color(0xFFFAC775) : const Color(0xFF633806);
    final amberIcon = isDark ? const Color(0xFFFAC775) : const Color(0xFF854F0B);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(l10n.backupScreenIntro,
                style: TextStyle(fontSize: 14, color: muted, height: 1.4)),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.backupPassphraseTitle,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('yedek_parola'),
                      controller: _pass,
                      enabled: !working,
                      obscureText: !_show,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.backupPassphrase,
                        errorText: _passError,
                        suffixIcon: toggle,
                      ),
                      onChanged: (_) => setState(() {
                        _passError = null;
                        _status = _Status.idle;
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('yedek_parola_tekrar'),
                      controller: _confirm,
                      enabled: !working,
                      obscureText: !_show,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.backupPassphraseConfirm,
                        errorText: _confirmError,
                      ),
                      onChanged: (_) => setState(() {
                        _confirmError = null;
                        _status = _Status.idle;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.backupPassphraseNote,
                      key: const Key('yedek_uyari'),
                      style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (result != null) ...[result, const SizedBox(height: 12)],
            ElevatedButton(
              key: const Key('yedek_al'),
              onPressed: working ? null : _export,
              child: Text(working ? l10n.backupWorking : l10n.backupCreateAction),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('yedek_geri_yukle'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(
                    color: isDark ? const Color(0xFFAFA9EC) : const Color(0xFF534AB7),
                    width: 1.5),
                foregroundColor:
                    isDark ? const Color(0xFFAFA9EC) : const Color(0xFF534AB7),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: working ? null : () => Navigator.of(context).pushNamed('/restore'),
              child: Text(l10n.backupRestoreAction),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: amberBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: amberIcon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.backupReplaceNote,
                      key: const Key('yedek_degisim_notu'),
                      style: TextStyle(fontSize: 13, color: amberFg, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
