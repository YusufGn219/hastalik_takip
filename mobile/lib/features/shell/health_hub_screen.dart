// Sağlık sekmesi: gruplu düz liste (İlaçlar, Hastalıklar, Ölçümler, Ben); her satır
// mevcut bir ekranı açar. Yalnız gezinme.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class HealthHubScreen extends StatelessWidget {
  const HealthHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 0, 6),
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
          ),
        );

    Widget row(Key key, Color tint, Color accent, String title, String hint,
            String route) =>
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            key: key,
            minVerticalPadding: 10,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(hint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(route),
          ),
        );

    const blue = (AppColors.medicationBg, AppColors.medication);
    const red = (AppColors.episodeBg, AppColors.episode);
    const purple = (AppColors.primary50, AppColors.primary600);
    const green = (AppColors.dailyBg, AppColors.daily);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              l10n.healthHubTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            header(l10n.healthGroupMedications),
            row(const Key('saglik_rutin'), blue.$1, blue.$2, l10n.homeRoutines,
                l10n.healthHubRoutinesHint, '/recurring'),
            row(const Key('saglik_ilaclar'), blue.$1, blue.$2,
                l10n.healthHubMedications, l10n.healthHubMedicationsHint,
                '/medication-log'),
            header(l10n.healthGroupConditions),
            row(const Key('saglik_kronik'), red.$1, red.$2, l10n.homeConditions,
                l10n.healthHubConditionsHint, '/chronic-conditions'),
            row(const Key('saglik_donemler'), red.$1, red.$2,
                l10n.healthHubEpisodes, l10n.healthHubEpisodesHint, '/episodes'),
            header(l10n.healthGroupMeasurements),
            row(const Key('saglik_olcumler'), purple.$1, purple.$2,
                l10n.homeReadings, l10n.healthHubReadingsHint, '/readings'),
            row(const Key('saglik_boykilo'), purple.$1, purple.$2,
                l10n.healthHubBody, l10n.healthHubBodyHint, '/body'),
            header(l10n.healthGroupMe),
            row(const Key('saglik_alanlar'), green.$1, green.$2,
                l10n.healthHubDailyFields, l10n.healthHubDailyFieldsHint,
                '/daily-fields'),
            row(const Key('saglik_profil'), green.$1, green.$2,
                l10n.healthHubProfile, l10n.healthHubProfileHint, '/profile'),
            row(const Key('saglik_ayarlar'), green.$1, green.$2,
                l10n.healthHubSettings, l10n.healthHubSettingsHint, '/settings'),
          ],
        ),
      ),
    );
  }
}
