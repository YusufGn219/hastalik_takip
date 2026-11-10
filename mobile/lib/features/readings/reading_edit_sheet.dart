// Ölçüm ekleme / düzenleme alt penceresi. Kuralları `ReadingService` uygular;
// burada yalnızca giriş alanları, birim çevirisi ve hata metinleri vardır.
// Başarıyla kaydedilince `true` ile kapanır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database/app_database.dart';
import '../../domain/errors.dart';
import '../../domain/reading_catalog.dart';
import '../../domain/services/reading_service.dart';
import '../../l10n/l10n.dart';
import '../medication/screens/recurring_screen.dart' show timePickerBuilder;
import 'reading_format.dart';

class ReadingEditSheet extends ConsumerStatefulWidget {
  const ReadingEditSheet({
    super.key,
    required this.kind,
    required this.unit,
    this.existing,
  });

  final ReadingKind kind;

  /// Açılışta seçili gösterim birimi.
  final String unit;

  /// Düzenlenen ölçüm; null ise yeni ölçüm.
  final Measurement? existing;

  @override
  ConsumerState<ReadingEditSheet> createState() => _ReadingEditSheetState();
}

class _ReadingEditSheetState extends ConsumerState<ReadingEditSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _note = TextEditingController();

  late String _unit;
  String? _context;
  late DateTime _at;
  bool _busy = false;
  String? _error;

  ReadingKind get _kind => widget.kind;
  String get _locale => Localizations.localeOf(context).toString();

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
    final m = widget.existing;
    if (m == null) {
      final now = ref.read(clockProvider)();
      _at = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    } else {
      // Kaydın kendi duvar saati (kayıt anındaki UTC farkıyla).
      final w = m.measuredAt.toUtc().add(Duration(minutes: m.utcOffsetMinutes));
      _at = DateTime(w.year, w.month, w.day, w.hour, w.minute);
      _context = m.context;
      _note.text = m.notes ?? '';
    }
  }

  // Yerel ayara bağlı biçim `initState`'te kullanılamaz; ilk çizimde doldurulur.
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = widget.existing;
    if (!_filled && m != null) {
      _filled = true;
      final unit = _kind.unitOf(_unit);
      _first.text = formatReadingNumber(_kind.fromBase(m.value, _unit), unit, _locale);
      final v2 = m.value2;
      if (v2 != null) {
        _second.text = formatReadingNumber(_kind.fromBase(v2, _unit), unit, _locale);
      }
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Virgül ya da nokta; boş ya da sayı değilse null.
  double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  /// Birim değişince yazılmış sayıları yeni birime çevirir.
  void _switchUnit(String code) {
    if (code == _unit) return;
    final from = _unit;
    final next = _kind.unitOf(code);
    String convert(String text) {
      final v = _parse(text);
      if (v == null) return text;
      return formatReadingNumber(_kind.fromBase(_kind.toBase(v, from), code), next, _locale);
    }

    setState(() {
      _first.text = convert(_first.text);
      _second.text = convert(_second.text);
      _unit = code;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_at.year, _at.month, _at.day),
      firstDate: DateTime(ReadingService.minYear),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _at = DateTime(picked.year, picked.month, picked.day, _at.hour, _at.minute);
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _at.hour, minute: _at.minute),
      builder: timePickerBuilder,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _at = DateTime(_at.year, _at.month, _at.day, picked.hour, picked.minute);
      _error = null;
    });
  }

  String _rangeText(double min, double max) {
    final l10n = context.l10n;
    final unit = _kind.unitOf(_unit);
    return l10n.readingErrRange(
      formatReadingNumber(_kind.fromBase(min, _unit), unit, _locale),
      formatReadingNumber(_kind.fromBase(max, _unit), unit, _locale),
      _unit,
    );
  }

  String _errorText(Object error) {
    final l10n = context.l10n;
    if (error is! RuleViolation) return l10n.readingErrGeneric;
    return switch (error.code) {
      RuleCodes.readingValueOutOfRange => _rangeText(_kind.min, _kind.max),
      RuleCodes.readingSecondValueOutOfRange => _rangeText(_kind.min2 ?? 0, _kind.max2 ?? 0),
      RuleCodes.readingSecondValueRequired => l10n.readingErrNumber,
      RuleCodes.readingFirstNotAboveSecond => l10n.readingErrOrder,
      RuleCodes.measurementDayInFuture => l10n.readingErrFuture,
      RuleCodes.measurementDayInvalid => l10n.readingErrDate,
      RuleCodes.readingNoteTooLong => l10n.readingErrNote,
      _ => l10n.readingErrGeneric,
    };
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final first = _parse(_first.text);
    final second = _kind.hasSecond ? _parse(_second.text) : null;
    if (first == null || (_kind.hasSecond && second == null)) {
      setState(() => _error = l10n.readingErrNumber);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(readingServiceProvider);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await service.add(
          type: _kind.type,
          value: first,
          value2: second,
          unit: _unit,
          context: _context,
          measuredAt: _at,
          notes: _note.text,
        );
      } else {
        await service.update(
          existing.id,
          value: first,
          value2: second,
          unit: _unit,
          context: _context,
          measuredAt: _at,
          notes: _note.text,
        );
      }
    } catch (e) {
      debugPrint('Ölçüm kaydedilemedi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e);
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final dateText = DateFormat('d MMMM y', _locale).format(_at);
    final timeText = DateFormat.Hm(_locale).format(_at);
    const decimal = TextInputType.numberWithOptions(decimal: true);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboard),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? l10n.readingAddTitle : l10n.readingEditTitle,
              style: text.titleMedium,
            ),
            Text(readingTypeName(l10n, _kind.type), style: text.bodyMedium),
            const SizedBox(height: 16),
            if (_kind.units.length > 1) ...[
              Text(l10n.readingUnitTitle, style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final u in _kind.units)
                    ChoiceChip(
                      key: Key('olcum_birim_${u.code}'),
                      label: Text(u.code),
                      selected: u.code == _unit,
                      onSelected: _busy ? null : (_) => _switchUnit(u.code),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              key: const Key('olcum_deger'),
              controller: _first,
              enabled: !_busy,
              keyboardType: decimal,
              decoration: InputDecoration(
                labelText: _kind.hasSecond
                    ? l10n.readingSystolicLabel(_unit)
                    : l10n.readingValueLabel(_unit),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_kind.hasSecond) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('olcum_deger2'),
                controller: _second,
                enabled: !_busy,
                keyboardType: decimal,
                decoration: InputDecoration(labelText: l10n.readingDiastolicLabel(_unit)),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ],
            if (_kind.contexts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.readingContextTitle, style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in _kind.contexts)
                    ChoiceChip(
                      key: Key('olcum_baglam_$c'),
                      label: Text(readingContextName(l10n, c)),
                      selected: _context == c,
                      // Seçiliye yeniden dokunmak bağlamı kaldırır.
                      onSelected: _busy
                          ? null
                          : (on) => setState(() => _context = on ? c : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('olcum_tarih'),
                    onTap: _busy ? null : _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.readingDateLabel,
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(dateText, key: const Key('olcum_tarih_deger')),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    key: const Key('olcum_saat'),
                    onTap: _busy ? null : _pickTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.readingTimeLabel,
                        suffixIcon: const Icon(Icons.schedule),
                      ),
                      child: Text(timeText, key: const Key('olcum_saat_deger')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('olcum_not'),
              controller: _note,
              enabled: !_busy,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.readingNoteLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('olcum_hata'),
                style: text.bodyMedium?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('olcum_kaydet'),
              onPressed: _busy ? null : _save,
              child: Text(l10n.readingSave),
            ),
          ],
        ),
      ),
    );
  }
}
