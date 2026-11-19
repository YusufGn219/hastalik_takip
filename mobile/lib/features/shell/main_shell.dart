// Ana kabuk: alt çubukta üç sekme (Bugün, Geçmiş, Sağlık) ve Bugün'de tek yüzen
// "+" düğmesi. Düğme dört seçenekli bir alt sayfa açar; her seçenek mevcut ekranı
// açar. Yalnız gezinme: veri ve servis katmanına dokunmaz.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart';
import 'health_hub_screen.dart';
import 'history_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  /// Sekmeler ilk açılışta kurulur (açılışta Geçmiş'in veri okuması beklemesin).
  final _visited = <bool>[true, false, false];

  /// Bugün sekmesine "yeniden oku" sinyali: "+" ile bir şey eklenince ya da
  /// sekmeye dönülünce.
  final _todayRefresh = ValueNotifier<int>(0);

  late final List<Widget> _tabs = <Widget>[
    HomeScreen(refresh: _todayRefresh),
    const HistoryScreen(),
    const HealthHubScreen(),
  ];

  @override
  void dispose() {
    _todayRefresh.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _visited[index] = true;
    });
    if (index == 0) _todayRefresh.value++;
  }

  Future<void> _openAddSheet() async {
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _AddSheet(),
    );
    if (route == null || !mounted) return;
    await Navigator.of(context).pushNamed(route);
    if (mounted) _todayRefresh.value++;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _visited[i] ? _tabs[i] : const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              key: const Key('kabuk_ekle'),
              tooltip: l10n.shellAddTooltip,
              onPressed: _openAddSheet,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        key: const Key('kabuk_sekmeler'),
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.shellTabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: l10n.shellTabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.shellTabHealth,
          ),
        ],
      ),
    );
  }
}

/// "+" alt sayfası: dört seçenek, seçilen rota üst sayfaya döner.
class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget option(Key key, IconData icon, String title, String route) => ListTile(
          key: key,
          leading: Icon(icon),
          title: Text(title),
          onTap: () => Navigator.of(context).pop(route),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.shellAddTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          option(const Key('ekle_ilac'), Icons.medication_outlined,
              l10n.shellAddMedication, '/medication-log'),
          option(const Key('ekle_semptom'), Icons.healing_outlined,
              l10n.shellAddSymptom, '/symptoms'),
          option(const Key('ekle_gunluk'), Icons.edit_note,
              l10n.shellAddDaily, '/daily-log'),
          option(const Key('ekle_olcum'), Icons.monitor_heart_outlined,
              l10n.shellAddReading, '/readings'),
        ],
      ),
    );
  }
}
