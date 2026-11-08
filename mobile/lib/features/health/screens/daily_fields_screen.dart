// Günlük ek alanlarını yönetme: hazır alanları açıp kapatma, kendi alanını ekleme
// ve düzenleme. Alanı kapatmak eski değerlerini silmez.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/enums.dart';
import '../../../domain/errors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n.dart';

class DailyFieldsScreen extends ConsumerWidget {
  const DailyFieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fields = ref.watch(dailyFieldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fieldsScreenTitle),
        actions: [
          IconButton(
            key: const Key('alan_ekle'),
            tooltip: l10n.fieldsAdd,
            icon: const Icon(Icons.add),
            onPressed: () => _openDialog(context, ref, null),
          ),
        ],
      ),
      body: fields.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.fieldsLoadError, key: const Key('alanlar_hata')),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('alanlar_tekrar'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => ref.invalidate(dailyFieldsProvider),
                  child: Text(l10n.fieldsRetry),
                ),
              ],
            ),
          ),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.fieldsIntro, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final f in list) _FieldTile(field: f),
          ],
        ),
      ),
    );
  }

  static Future<void> _openDialog(
    BuildContext context,
    WidgetRef ref,
    DailyField? field,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FieldDialog(field: field),
    );
    if (saved == true) {
      ref.invalidate(dailyFieldsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.fieldsSaved)),
        );
      }
    }
  }
}

String _kindLabel(AppLocalizations l10n, String kind) {
  switch (kind) {
    case DailyFieldKinds.scale:
      return l10n.fieldsKindScale;
    case DailyFieldKinds.yesNo:
      return l10n.fieldsKindYesNo;
    default:
      return l10n.fieldsKindNumber;
  }
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class _FieldTile extends ConsumerWidget {
  const _FieldTile({required this.field});

  final DailyField field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final builtin = field.builtinKey != null;
    final parts = <String>[
      builtin ? l10n.fieldsBuiltin : _kindLabel(l10n, field.kind),
      if (field.kind == DailyFieldKinds.number)
        '${_trim(field.minValue)}–${_trim(field.maxValue)}'
            '${field.unit.isEmpty ? '' : ' ${field.unit}'}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(field.name),
        subtitle: Text(parts.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!builtin)
              IconButton(
                key: Key('alan_duzenle_${field.id}'),
                tooltip: l10n.fieldsEditTitle,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    DailyFieldsScreen._openDialog(context, ref, field),
              ),
            Switch(
              key: Key('alan_ac_${field.id}'),
              value: field.isActive,
              onChanged: (value) async {
                try {
                  await ref
                      .read(dailyFieldServiceProvider)
                      .setActive(field.id, value);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.fieldsToggleError)),
                    );
                  }
                }
                ref.invalidate(dailyFieldsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Alan ekleme / düzenleme penceresi. Kaydedilirse `true` ile kapanır.
class _FieldDialog extends ConsumerStatefulWidget {
  const _FieldDialog({required this.field});

  /// Düzenlenen alan; yeni alanda null.
  final DailyField? field;

  @override
  ConsumerState<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends ConsumerState<_FieldDialog> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late String _kind;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final f = widget.field;
    _name = TextEditingController(text: f?.name ?? '');
    _unit = TextEditingController(text: f?.unit ?? '');
    _min = TextEditingController(text: f == null ? '' : _trim(f.minValue));
    _max = TextEditingController(text: f == null ? '' : _trim(f.maxValue));
    _kind = f?.kind ?? DailyFieldKinds.number;
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// Boşsa null, okunamıyorsa NaN.
  double? _parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.')) ?? double.nan;
  }

  String _messageFor(AppLocalizations l10n, String code) {
    switch (code) {
      case RuleCodes.dailyFieldNameEmpty:
        return l10n.fieldsErrNameEmpty;
      case RuleCodes.dailyFieldNameTooLong:
        return l10n.fieldsErrNameTooLong;
      case RuleCodes.dailyFieldNameExists:
        return l10n.fieldsErrNameExists;
      case RuleCodes.dailyFieldUnitTooLong:
        return l10n.fieldsErrUnitTooLong;
      case RuleCodes.dailyFieldRangeInvalid:
        return l10n.fieldsErrRange;
      case RuleCodes.dailyFieldTooMany:
        return l10n.fieldsErrTooMany;
      default:
        return l10n.fieldsSaveError;
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final min = _parse(_min.text);
    final max = _parse(_max.text);
    if ((min != null && min.isNaN) || (max != null && max.isNaN)) {
      setState(() => _error = l10n.fieldsErrRange);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(dailyFieldServiceProvider);
    try {
      final f = widget.field;
      if (f == null) {
        await service.create(
          name: _name.text,
          kind: _kind,
          unit: _unit.text,
          min: min,
          max: max,
        );
      } else {
        await service.update(
          f.id,
          name: _name.text,
          unit: _unit.text,
          min: min,
          max: max,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on RuleViolation catch (e) {
      if (mounted) setState(() => _error = _messageFor(l10n, e.code));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.fieldsSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final creating = widget.field == null;
    final isNumber = _kind == DailyFieldKinds.number;

    return AlertDialog(
      title: Text(creating ? l10n.fieldsAddTitle : l10n.fieldsEditTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('alan_ad'),
              controller: _name,
              decoration: InputDecoration(labelText: l10n.fieldsName),
            ),
            const SizedBox(height: 12),
            if (creating)
              DropdownButtonFormField<String>(
                key: const Key('alan_tur'),
                initialValue: _kind,
                decoration: InputDecoration(labelText: l10n.fieldsKind),
                items: [
                  for (final k in DailyFieldKinds.all)
                    DropdownMenuItem(value: k, child: Text(_kindLabel(l10n, k))),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
            if (isNumber) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('alan_birim'),
                controller: _unit,
                decoration: InputDecoration(labelText: l10n.fieldsUnit),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('alan_min'),
                controller: _min,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: l10n.fieldsMin),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('alan_max'),
                controller: _max,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: l10n.fieldsMax),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('alan_hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('alan_vazgec'),
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const Key('alan_kaydet'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.fieldsSave),
        ),
      ],
    );
  }
}
