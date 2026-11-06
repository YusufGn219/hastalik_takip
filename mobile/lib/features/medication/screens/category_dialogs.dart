// İlaç kategorisi pencereleri: ad girişi ve "Kategoriler" yönetimi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/errors.dart';
import '../../../l10n/app_localizations.dart';

/// Kategori işlemindeki hatayı kullanıcıya gösterilecek metne çevirir.
String categoryErrorText(Object error, AppLocalizations l10n) {
  if (error is RuleViolation) {
    switch (error.code) {
      case RuleCodes.categoryNameEmpty:
        return l10n.medCatErrorEmpty;
      case RuleCodes.categoryNameTooLong:
        return l10n.medCatErrorTooLong;
      case RuleCodes.categoryNameExists:
        return l10n.medCatErrorExists;
    }
  }
  return l10n.medCatErrorGeneric;
}

/// Tek satırlık ad penceresi. Kırpılmış, boş olmayan adı döndürür; iptalde null.
Future<String?> showCategoryNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CategoryNameDialog(title: title, initial: initial),
  );
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.medCatNameLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.medLogCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.medCatSave)),
      ],
    );
  }
}

/// "Kategoriler" yönetimi: listele, ekle, adını değiştir, sil. Pencere
/// kapanınca çağıran ekran listeleri yeniden okur.
class CategoryManagerDialog extends ConsumerStatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  ConsumerState<CategoryManagerDialog> createState() =>
      _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends ConsumerState<CategoryManagerDialog> {
  final _newController = TextEditingController();
  List<MedicationCategory> _categories = [];
  bool _loadFailed = false;
  Object? _error; // en son işlem hatası

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await ref.read(medicationServiceProvider).categories();
      if (!mounted) return;
      setState(() {
        _categories = list;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  /// İşlemi çalıştırır; hata olursa mesaj gösterir, olmazsa listeyi tazeler.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      return;
    }
    await _reload();
  }

  Future<void> _add() async {
    final name = _newController.text;
    if (name.trim().isEmpty) return;
    await _run(() async {
      await ref.read(medicationServiceProvider).createCategory(name);
      _newController.clear();
    });
  }

  Future<void> _rename(MedicationCategory c) async {
    final l10n = AppLocalizations.of(context);
    final name = await showCategoryNameDialog(
      context,
      title: l10n.medCatRenameTitle,
      initial: c.name,
    );
    if (name == null || !mounted) return;
    await _run(
        () => ref.read(medicationServiceProvider).renameCategory(c.id, name));
  }

  Future<void> _delete(MedicationCategory c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.medCatDeleteTitle),
        content: Text(l10n.medCatDeleteBody(c.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.medLogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.medCatDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => ref.read(medicationServiceProvider).deleteCategory(c.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorText = _loadFailed
        ? l10n.medCatLoadError
        : (_error == null ? null : categoryErrorText(_error!, l10n));
    return AlertDialog(
      title: Text(l10n.medCatTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: _categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l10n.medCatEmpty),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in _categories)
                          ListTile(
                            key: ValueKey('cat-${c.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: l10n.medCatRename,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _rename(c),
                                ),
                                IconButton(
                                  tooltip: l10n.medCatDelete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(c),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newController,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: l10n.medCatNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: Text(l10n.medCatAdd)),
              ],
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorText,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.medCatClose),
        ),
      ],
    );
  }
}
