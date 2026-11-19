// Taslaktaki "hızlı ekle" alt sayfası ve içinde kullanılan ortak parçalar:
// köşeleri yuvarlak, tutamaçlı, başlık + kapat (X) satırlı, altında sabit birincil
// düğmeli sayfa; "− değer +" adım alanı; 1-5 sayı düğmeleri.
// Yalnız görünüm: kayıt mantığı ekranların kendisindedir.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Altta kayan, arkasını karartan ve dışına dokununca kapanan sayfa rotası.
/// `onGenerateRoute` içinde adlı rotalar için kullanılır.
Route<T> formSheetRoute<T>(RouteSettings settings, WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    settings: settings,
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x731A1A2E),
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation),
      child: child,
    ),
  );
}

/// Alt sayfa gövdesi. [footer] varsa içerikten ayrı, altta sabit durur (klavye
/// açılınca klavyenin üstüne çıkar). Dışına dokunmak ya da X sayfayı kapatır.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.onClose,
  });

  final String title;
  final Widget child;
  final Widget? footer;

  /// Boşsa `Navigator.pop`.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final close = onClose ?? () => Navigator.of(context).maybePop();
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (media.size.height - keyboard) * 0.94,
                ),
                child: Material(
                  key: const Key('form_sheet'),
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    bottom: keyboard == 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                key: const Key('sayfa_kapat'),
                                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                                iconSize: 22,
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                onPressed: close,
                                icon: Icon(Icons.close,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                            child: child,
                          ),
                        ),
                        if (footer != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: footer,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Taslaktaki "− değer +" satırı: solda etiket, sağda 44 px eksi düğmesi, değer
/// alanı ve artı düğmesi. Değer alanı gerçek bir metin alanıdır ([controller]);
/// düğmeler onu [step] kadar değiştirir ve [min]..[max] içinde tutar, böylece
/// elle yazmak da çalışır. [format] sayıyı yerel ondalık ayracıyla yazar.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.label,
    required this.controller,
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    this.start,
    this.onChanged,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;

  /// Alan boşken ilk artı/eksi basışında başlanacak değer.
  final double? start;
  final VoidCallback? onChanged;
  final Key? fieldKey;

  double? get _current => double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _bump(double delta) {
    final base = _current ?? start ?? min;
    final next = (base + delta).clamp(min, max).toDouble();
    controller.text = format(next);
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    Widget button(String symbol, String tip, VoidCallback onTap) => SizedBox(
          width: 44,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
              backgroundColor: theme.cardColor,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            onPressed: onTap,
            child: Semantics(
              label: tip,
              child: Text(symbol, style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          button('−', 'Azalt', () => _bump(-step)),
          SizedBox(
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44,
                  child: TextField(
                    key: fieldKey,
                    controller: controller,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged?.call(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      // Değer yokken boşluk yerine soluk çizgi (taslakta değer hep görünür).
                      hintText: '–',
                      hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
              ],
            ),
          ),
          button('+', 'Artır', () => _bump(step)),
        ],
      ),
    );
  }
}

/// Taslaktaki 1-5 sayı düğmeleri (ruh hali, enerji): seçili olan koyu yeşil,
/// diğerleri açık yeşil zeminli. [label] düğme grubunun başlığıdır.
class ScaleButtons extends StatelessWidget {
  const ScaleButtons({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.count = 5,
    this.keyPrefix = 'olcek',
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int count;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppColors.daily : const Color(0xFF2B4A0A);
    final bg = isDark ? AppColors.daily.withValues(alpha: 0.16) : AppColors.dailyBg;
    final fg = isDark ? const Color(0xFFDDF0C4) : const Color(0xFF2B4A0A);
    final border = AppColors.daily.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var n = 1; n <= count; n++) ...[
                if (n > 1) const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: Material(
                      color: n == value ? selectedBg : bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: n == value ? selectedBg : border),
                      ),
                      child: InkWell(
                        key: Key('${keyPrefix}_$n'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onChanged(n),
                        child: Center(
                          child: Text(
                            '$n',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: n == value ? Colors.white : fg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
