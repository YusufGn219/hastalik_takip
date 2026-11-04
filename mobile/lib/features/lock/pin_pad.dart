import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Girilen hane sayısını gösteren noktalar. [slots] kadar nokta çizilir,
/// ilk [filled] tanesi doludur.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, required this.slots, this.error = false});

  final int filled;
  final int slots;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Row(
      key: const Key('pin_noktalar'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < slots; i++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// 0-9 rakam tuş takımı. Alt satırın solu [bottomLeft] (ör. parmak izi düğmesi),
/// sağı silme tuşudur. Üst katman (Overlay) bulunmayabileceği için ipucu
/// (tooltip) kullanılmaz; erişilebilirlik için [backspaceLabel] verilir.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.backspaceLabel,
    this.bottomLeft,
    this.enabled = true,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final String backspaceLabel;
  final Widget? bottomLeft;
  final bool enabled;

  Widget _key(BuildContext context, String digit) {
    return _PadButton(
      key: Key('pin_$digit'),
      onTap: enabled ? () => onDigit(digit) : null,
      child: Text(digit, style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> children) => Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([for (final d in ['1', '2', '3']) _key(context, d)]),
        row([for (final d in ['4', '5', '6']) _key(context, d)]),
        row([for (final d in ['7', '8', '9']) _key(context, d)]),
        row([
          SizedBox(width: 88, height: 72, child: Center(child: bottomLeft)),
          _key(context, '0'),
          _PadButton(
            key: const Key('pin_sil'),
            onTap: enabled ? onBackspace : null,
            child: Semantics(label: backspaceLabel, child: const Icon(Icons.backspace_outlined)),
          ),
        ]),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 72,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Center(child: child),
      ),
    );
  }
}

/// "N sn" ya da "M dk SS sn" biçiminde kalan süre (en az 1 sn).
String formatWait(AppLocalizations l10n, Duration d) {
  final total = d.inSeconds < 1 ? 1 : d.inSeconds;
  if (total < 60) return l10n.waitSeconds(total);
  return l10n.waitMinutes(total ~/ 60, (total % 60).toString().padLeft(2, '0'));
}
