// Veritabanı açılamazsa gösterilen sade ekran (şifreli dosya ya da anahtar
// sorunu). Uygulamanın geri kalanı yüklenmez.

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.dbOpenErrorTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.dbOpenErrorBody),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
