import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';
import 'pin_setup_screen.dart';
import 'recovery_code_screen.dart';

/// Kilidi kurma akışı: PIN belirle (iki kez) → kilidi kur → kurtarma kodunu bir
/// kez göster. Tamamlanırsa true; PIN aşamasında vazgeçilirse false (hiçbir şey
/// kaydedilmez). Ayarlar ekranı (Sprint 3 sonrası) ve ilk açılış önerisi bunu çağırır.
Future<bool> runEnableLockFlow(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  final pin = await navigator.push<String>(MaterialPageRoute(builder: (_) => const PinSetupScreen()));
  if (pin == null) return false;
  final code = await ref.read(appLockProvider.notifier).enable(pin);
  await navigator.push<void>(MaterialPageRoute(builder: (_) => RecoveryCodeScreen(code: code)));
  return true;
}
