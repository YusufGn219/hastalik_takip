// "Yedekten geri yükle" ekranı: dosya seç → parola → (kilit açıksa PIN) → onay →
// geri yükle → uygulama baştan kurulur. Mevcut veri yedektekiyle DEĞİŞTİRİLİR.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/backup/backup_service.dart';
import '../../l10n/l10n.dart';
import '../lock/app_lock_controller.dart';
import '../lock/app_lock_platform.dart';
import '../lock/pin_setup_screen.dart';
import 'backup_platform.dart';
import 'backup_restorer.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final _pass = TextEditingController();
  File? _file;
  bool _show = false;
  bool _working = false;
  String? _fileError;
  String? _passError;
  String? _resultError;

  /// Seçici kopyasını silmek için tutulur (`dispose` içinde `ref` okunmaz).
  late final BackupRestorer _restorer = ref.read(backupRestorerProvider);

  @override
  void dispose() {
    _pass.dispose();
    // Seçici kopyası yanlış parola gibi hatalarda yeniden denemek için kalır;
    // ekrandan çıkılınca silinir.
    final file = _file;
    if (file != null) unawaited(_discard(file));
    super.dispose();
  }

  Future<void> _discard(File file) async {
    try {
      await _restorer.discardPickedCopy(file);
    } catch (_) {
      // Önbellek kopyası silinemezse akış durmaz.
    }
  }

  Future<void> _pick() async {
    final file = await ref.read(backupFilePickerProvider).pick();
    if (file == null || !mounted) return;
    final previous = _file;
    if (previous != null && previous.path != file.path) await _discard(previous);
    if (!mounted) return;
    setState(() {
      _file = file;
      _fileError = null;
      _resultError = null;
    });
  }

  String _errorText(Object error) {
    final l10n = context.l10n;
    if (error is BackupException) {
      return switch (error.failure) {
        BackupFailure.wrongPassphraseOrCorrupt => l10n.restoreErrWrong,
        BackupFailure.newerVersion => l10n.restoreErrNewer,
        BackupFailure.notABackup => l10n.restoreErrNotBackup,
        BackupFailure.io => l10n.restoreErrIo,
      };
    }
    return l10n.restoreErrIo;
  }

  Future<void> _restore() async {
    if (_working) return;
    final l10n = context.l10n;
    final file = _file;
    final pass = _pass.text;
    setState(() {
      _fileError = file == null ? l10n.restoreNeedFile : null;
      _passError = pass.isEmpty ? l10n.restoreNeedPassphrase : null;
      _resultError = null;
    });
    if (file == null || pass.isEmpty) return;
    FocusScope.of(context).unfocus();

    // Kilit açıksa önce PIN (silmedekiyle aynı koruma).
    if (ref.read(appLockProvider).enabled) {
      final pin = await confirmCurrentPin(context);
      if (pin == null || !mounted) return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmBody),
        actions: [
          TextButton(
            key: const Key('geri_yukle_vazgec'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('geri_yukle_onay'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.restoreAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Başarıda uygulama baştan kurulur ve bu ekran ağaçtan kalkar; önce gerekenleri al.
    final restorer = _restorer;
    final restart = ref.read(appRestartProvider);
    setState(() => _working = true);
    String? error;
    try {
      await restorer.run(backup: file, passphrase: pass);
    } catch (e) {
      // Parola ve içerik günlüğe yazılmaz; yalnız hata türü.
      debugPrint('Geri yüklenemedi: ${e.runtimeType}');
      error = _errorText(e);
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _working = false;
        _resultError = error;
      });
      return;
    }

    // Başarılı: seçici kopyası artık gerekmez.
    await _discard(file);
    _file = null;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreDoneTitle),
        content: Text(l10n.restoreDoneBody),
        actions: [
          TextButton(
            key: const Key('geri_yukle_tamam'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    await restart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.restoreTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.restoreIntro, style: text.bodyMedium),
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
                        l10n.restoreWarning,
                        key: const Key('geri_yukle_uyari'),
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('geri_yukle_sec'),
              onPressed: _working ? null : _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.restorePick),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _file == null ? l10n.restoreNoFile : p.basename(_file!.path),
                key: const Key('geri_yukle_dosya'),
                style: text.bodySmall,
              ),
            ),
            if (_fileError != null)
              Text(_fileError!, key: const Key('geri_yukle_dosya_hata'), style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('geri_yukle_parola'),
              controller: _pass,
              enabled: !_working,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.restorePassphrase,
                errorText: _passError,
                suffixIcon: IconButton(
                  key: const Key('geri_yukle_goster'),
                  tooltip: _show ? l10n.backupHidePassphrase : l10n.backupShowPassphrase,
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              onChanged: (_) => setState(() {
                _passError = null;
                _resultError = null;
              }),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('geri_yukle_baslat'),
              onPressed: _working ? null : _restore,
              child: Text(_working ? l10n.restoreWorking : l10n.restoreAction),
            ),
            if (_resultError != null) ...[
              const SizedBox(height: 16),
              Text(_resultError!, key: const Key('geri_yukle_sonuc'), style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
