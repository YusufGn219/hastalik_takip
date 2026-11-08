// "Yedek al" ekranı: parolayı iki kez alır, yedeği şifreleyip kullanıcının seçtiği
// yere kaydettirir. Parola hiçbir yere kaydedilmez ve günlüğe yazılmaz.

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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final working = _status == _Status.working;

    final toggle = IconButton(
      key: const Key('yedek_goster'),
      tooltip: _show ? l10n.backupHidePassphrase : l10n.backupShowPassphrase,
      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _show = !_show),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.backupIntro, style: text.bodyMedium),
            const SizedBox(height: 16),
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.backupWarning,
                        key: const Key('yedek_uyari'),
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('yedek_al'),
              onPressed: working ? null : _export,
              child: Text(working ? l10n.backupWorking : l10n.backupAction),
            ),
            const SizedBox(height: 16),
            if (_status == _Status.done)
              Text(l10n.backupDone, key: const Key('yedek_sonuc'), style: TextStyle(color: scheme.primary)),
            if (_status == _Status.cancelled) Text(l10n.backupCancelled, key: const Key('yedek_sonuc')),
            if (_status == _Status.failed)
              Text(l10n.backupFailed, key: const Key('yedek_sonuc'), style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
    );
  }
}
