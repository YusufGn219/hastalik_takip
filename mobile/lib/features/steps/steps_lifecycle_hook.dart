// Açılış okuma yolu: uygulama açılırken ve arka plandan öne gelirken adım sayacını
// bir kez okutur. Saatlik arka plan rutininden BAĞIMSIZDIR. Arayüzü geciktirmez
// (sonuç beklenmez) ve hiçbir hata kullanıcıya yansımaz.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class StepsLifecycleHook extends ConsumerStatefulWidget {
  const StepsLifecycleHook({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StepsLifecycleHook> createState() => _StepsLifecycleHookState();
}

class _StepsLifecycleHookState extends ConsumerState<StepsLifecycleHook>
    with WidgetsBindingObserver {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // İlk çizimden sonra: açılışı geciktirmesin.
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _read();
  }

  Future<void> _read() async {
    if (_running || !mounted) return;
    _running = true;
    try {
      await ref.read(stepTrackingProvider).onAppOpen();
    } catch (_) {
      // Adım okuması hiçbir zaman uygulamayı etkilemez.
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
