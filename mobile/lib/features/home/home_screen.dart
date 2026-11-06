// GEÇİCİ ana ekran (Sprint 3). Üç çekirdek akışa ulaşmak için sade bir menü;
// Sprint 5'te gerçek zaman çizelgesi ekranıyla değişecek.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../lock/lock_settings_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                l10n.homeSubtitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _HomeTile(
              icon: Icons.edit_note,
              color: AppColors.daily,
              background: AppColors.dailyBg,
              title: l10n.homeDailyLog,
              hint: l10n.homeDailyLogHint,
              route: '/daily-log',
            ),
            _HomeTile(
              icon: Icons.healing,
              color: AppColors.symptom,
              background: AppColors.symptomBg,
              title: l10n.homeSymptoms,
              hint: l10n.homeSymptomsHint,
              route: '/symptoms',
            ),
            _HomeTile(
              icon: Icons.timeline,
              color: AppColors.episode,
              background: AppColors.episodeBg,
              title: l10n.homeEpisodes,
              hint: l10n.homeEpisodesHint,
              route: '/episodes',
            ),
            _HomeTile(
              icon: Icons.medication,
              color: AppColors.medication,
              background: AppColors.medicationBg,
              title: l10n.homeMedication,
              hint: l10n.homeMedicationHint,
              route: '/medication-log',
            ),
            _HomeTile(
              icon: Icons.monitor_heart_outlined,
              color: AppColors.medication,
              background: AppColors.medicationBg,
              title: l10n.homeConditions,
              hint: l10n.homeConditionsHint,
              route: '/chronic-conditions',
            ),
            // GEÇİCİ: ayarlar ekranı gelene kadar kilidi buradan yönetiyoruz.
            const AppLockSettingsCard(),
          ],
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.hint,
    required this.route,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String hint;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: background,
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(hint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}
