import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';
import 'app_lock_platform.dart';
import 'lock_screen.dart';

/// Uygulamanın üstüne kilit ekranını bindiren kapı. `MaterialApp.builder` içinde
/// kullanılır; altındaki gezgin canlı kalır (kilit açılınca kaldığı yerden devam
/// eder), ama kilitliyken dokunma ve erişilebilirlik tarafından görülmez.
/// Bildirim yönlendirmeleri de bu kapının arkasında kalır.
///
/// Kilit ekranı kendi küçük gezginini taşır (kurtarma kodu ekranları ve
/// pencereler uygulamanın gezginine değil buna açılır; kilit açılınca birlikte
/// kalkarlar). Ayrıca arka plana gidiş/dönüşü kilit denetleyicisine bildirir ve
/// kilit kuruluyken ekran görüntüsünü engeller.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  final _lockNavigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySecurity(ref.read(appLockProvider).enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _applySecurity(bool enabled) {
    ref.read(screenSecurityProvider).setSecure(enabled);
  }

  /// Sistem geri tuşu: kilit ekranının içinde bir üst ekran (kurtarma, PIN kurulumu)
  /// açıksa ona döner. Uygulamanın kendi gezgini bu çağrıyı önce alır; çekecek
  /// rotası yoksa sıra buraya gelir. Kurtarma kodu ekranı geri dönüşü kendi
  /// engeller; tuş yutulur, uygulama kapanmaz.
  @override
  Future<bool> didPopRoute() async {
    final nav = _lockNavigator.currentState;
    if (nav == null || !nav.canPop()) return false;
    await nav.maybePop();
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        lock.appLeft();
      case AppLifecycleState.resumed:
        lock.appReturned();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appLockProvider.select((s) => s.enabled), (_, enabled) => _applySecurity(enabled));
    final locked = ref.watch(appLockProvider.select((s) => s.enabled && s.locked));

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: widget.child),
        ),
        if (locked)
          Positioned.fill(
            // Kilit ekranlarının SnackBar'ı uygulamanın Scaffold'una düşmesin.
            child: ScaffoldMessenger(
              // İç gezgin uygulamanın HeroController'ını paylaşamaz (çöker).
              child: HeroControllerScope.none(
                child: Navigator(
                  key: _lockNavigator,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const LockScreen()),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
