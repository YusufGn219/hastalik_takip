import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Girilen hane sayısını gösteren noktalar (taslaktaki "Kilit" panosu): 14 px,
/// dolu olan ana renkte, boş olan yalnız çerçeveli. [slots] kadar nokta çizilir,
/// ilk [filled] tanesi doludur.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, required this.slots, this.error = false});

  final int filled;
  final int slots;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = error
        ? scheme.error
        : (isDark ? AppColors.primary200 : AppColors.primary600);
    final emptyBorder = error ? scheme.error : scheme.onSurface.withValues(alpha: 0.3);
    return Row(
      key: const Key('pin_noktalar'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < slots; i++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? color : Colors.transparent,
              border: i < filled ? null : Border.all(color: emptyBorder, width: 2),
            ),
          ),
      ],
    );
  }
}

/// 0-9 rakam tuş takımı: 72×60 yuvarlak köşeli tuşlar, 3 sütun (taslaktaki gibi).
/// Alt satırın solu [bottomLeft] (boşsa boş hücre), sağı silme tuşudur. Üst
/// katman (Overlay) bulunmayabileceği için ipucu (tooltip) kullanılmaz;
/// erişilebilirlik için [backspaceLabel] verilir.
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
      child: Text(
        digit,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> children) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              children[i],
            ],
          ],
        );
    const gap = SizedBox(height: 12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([for (final d in ['1', '2', '3']) _key(context, d)]),
        gap,
        row([for (final d in ['4', '5', '6']) _key(context, d)]),
        gap,
        row([for (final d in ['7', '8', '9']) _key(context, d)]),
        gap,
        row([
          SizedBox(width: 72, height: 60, child: Center(child: bottomLeft)),
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
    final theme = Theme.of(context);
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: theme.cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(width: 72, height: 60, child: Center(child: child)),
        ),
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
