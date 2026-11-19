// Ekranın altına sabitlenen birincil eylem çubuğu (ör. "Kaydet"): içerik kayarken
// düğme hep görünür kalır; varsa iletisi (hata/başarı) düğmenin hemen üstünde durur.
// `Scaffold.bottomNavigationBar` içinde kullanılır.

import 'package:flutter/material.dart';

class PinnedActionBar extends StatelessWidget {
  const PinnedActionBar({super.key, required this.child, this.message});

  /// Birincil düğme; tam genişlikte çizilir.
  final Widget child;

  /// Düğmenin üstündeki ileti (hata kutusu, başarı yazısı); yoksa null.
  final Widget? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null) ...[message!, const SizedBox(height: 8)],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
