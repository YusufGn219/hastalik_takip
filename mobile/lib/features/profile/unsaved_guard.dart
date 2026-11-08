// Kaydedilmemiş değişikliği olan bir ekrandan geri tuşuyla çıkarken onay sorar.
// Kaydedince ekranın kendi `Navigator.pop` çağrısı bu denetimden geçmez.

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });

  /// Kaydedilmemiş değişiklik var mı.
  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final l10n = ctx.l10n;
            return AlertDialog(
              title: Text(l10n.unsavedTitle),
              content: Text(l10n.unsavedBody),
              actions: [
                TextButton(
                  key: const Key('degisiklik_kal'),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.unsavedStay),
                ),
                TextButton(
                  key: const Key('degisiklik_cik'),
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  child: Text(l10n.unsavedLeave),
                ),
              ],
            );
          },
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
