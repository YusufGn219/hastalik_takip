// Günlük ekranında çekirdek dört alanın altında görünen "Ek alanlar" kartı.

import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/l10n.dart';
import '../extra_fields_controller.dart';

class ExtraFieldsSection extends StatelessWidget {
  const ExtraFieldsSection({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final ExtraFieldsController controller;

  /// "Alanları düzenle" düğmesi.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (controller.status != ExtraFieldsStatus.ready) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fields = controller.fields;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1825) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.extraFieldsTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const Key('gunluk_alanlari_duzenle'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: onEdit,
                child: Text(l10n.extraFieldsEdit),
              ),
            ],
          ),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.extraFieldsEmpty,
                key: const Key('ek_alan_bos'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final f in fields) ...[
            const SizedBox(height: 12),
            _FieldInput(controller: controller, field: f),
          ],
        ],
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({required this.controller, required this.field});

  final ExtraFieldsController controller;
  final DailyField field;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = field.unit.isEmpty ? field.name : '${field.name} (${field.unit})';

    final Widget input;
    if (field.kind == DailyFieldKinds.number) {
      input = TextField(
        key: Key('ek_alan_${field.id}'),
        controller: controller.textOf(field.id),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: '${_trim(field.minValue)}–${_trim(field.maxValue)}',
          isDense: true,
        ),
      );
    } else if (field.kind == DailyFieldKinds.scale) {
      input = Wrap(
        spacing: 8,
        children: [
          for (var n = 1; n <= 5; n++)
            ChoiceChip(
              key: Key('ek_alan_${field.id}_$n'),
              label: Text('$n'),
              selected: controller.pickedOf(field.id) == n.toDouble(),
              onSelected: (_) => controller.pick(field.id, n.toDouble()),
            ),
        ],
      );
    } else {
      input = Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            key: Key('ek_alan_${field.id}_evet'),
            label: Text(l10n.extraFieldYes),
            selected: controller.pickedOf(field.id) == 1,
            onSelected: (_) => controller.pick(field.id, 1),
          ),
          ChoiceChip(
            key: Key('ek_alan_${field.id}_hayir'),
            label: Text(l10n.extraFieldNo),
            selected: controller.pickedOf(field.id) == 0,
            onSelected: (_) => controller.pick(field.id, 0),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        input,
      ],
    );
  }
}

/// 20.0 → "20", 2.5 → "2.5".
String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
