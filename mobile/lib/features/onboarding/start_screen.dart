// Açılış kapısı ("/" rotası): tanıtım daha önce görülmediyse onu, görüldüyse ana
// ekranı gösterir. "Görüldü" bilgisi şifreli veritabanındaki ayarlar tablosunda
// durur; "Tüm veriyi sil" sonrası uygulama baştan kurulduğu için tanıtım yeniden
// çıkar. Uygulama kilidi bunun üstünde, `MaterialApp.builder` içinde çalışır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../home/home_screen.dart';
import 'onboarding_screen.dart';

/// Ayarlar tablosundaki anahtar; değer `'true'` ise tanıtım görülmüştür.
const onboardingDoneKey = 'onboarding_done';

class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  /// `null`: ayar henüz okunmadı.
  bool? _done;

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool done;
    try {
      done = await _settings.get(onboardingDoneKey) == 'true';
    } catch (_) {
      // Ayar okunamazsa kullanıcıyı tanıtımda hapsetme; ana ekrana geç.
      done = true;
    }
    if (!mounted) return;
    setState(() => _done = done);
  }

  Future<void> _finish() async {
    try {
      await _settings.set(onboardingDoneKey, 'true');
    } catch (_) {
      // Yazılamazsa tanıtım bir sonraki açılışta yeniden çıkar; akış durmaz.
    }
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done == null) return const Scaffold();
    return done ? const HomeScreen() : OnboardingScreen(onDone: _finish);
  }
}
