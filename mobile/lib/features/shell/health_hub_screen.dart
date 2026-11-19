// Sağlık sekmesi: düz liste; her satır mevcut bir ekranı açar. Yalnız gezinme.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class HealthHubScreen extends StatelessWidget {
  const HealthHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget row(Key key, IconData icon, String title, String route) => ListTile(
          key: key,
          minVerticalPadding: 12,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed(route),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthHubTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            row(const Key('saglik_rutin'), Icons.repeat, l10n.homeRoutines,
                '/recurring'),
            row(const Key('saglik_ilaclar'), Icons.medication_outlined,
                l10n.healthHubMedications, '/medication-log'),
            row(const Key('saglik_kronik'), Icons.monitor_heart_outlined,
                l10n.homeConditions, '/chronic-conditions'),
            row(const Key('saglik_olcumler'), Icons.favorite_border,
                l10n.homeReadings, '/readings'),
            row(const Key('saglik_boykilo'), Icons.straighten,
                l10n.healthHubBody, '/body'),
            row(const Key('saglik_alanlar'), Icons.tune,
                l10n.healthHubDailyFields, '/daily-fields'),
            row(const Key('saglik_profil'), Icons.person_outline,
                l10n.healthHubProfile, '/profile'),
            row(const Key('saglik_ayarlar'), Icons.settings_outlined,
                l10n.healthHubSettings, '/settings'),
          ],
        ),
      ),
    );
  }
}
