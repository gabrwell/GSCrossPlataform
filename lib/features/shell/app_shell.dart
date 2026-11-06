import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../state/alerts_controller.dart';

/// Navegação principal: barra inferior no celular e trilho lateral em telas
/// largas. O contador de alertas vem do estado global.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _labels = ['Início', 'Painéis', 'Alertas', 'Mapa', 'Cidadão'];
  static const _icons = [
    Icons.home_outlined,
    Icons.insights_outlined,
    Icons.notifications_outlined,
    Icons.map_outlined,
    Icons.campaign_outlined,
  ];
  static const _selectedIcons = [
    Icons.home,
    Icons.insights,
    Icons.notifications,
    Icons.map,
    Icons.campaign,
  ];

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final pending = context.select<AlertsController, int>(
      (c) => c.pendingCount,
    );

    Widget icon(int index, IconData data) {
      if (index != 2 || pending == 0) return Icon(data);
      return Badge(label: Text('$pending'), child: Icon(data));
    }

    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _labels.length; i++)
                  NavigationRailDestination(
                    icon: icon(i, _icons[i]),
                    selectedIcon: icon(i, _selectedIcons[i]),
                    label: Text(_labels[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(
              icon: icon(i, _icons[i]),
              selectedIcon: icon(i, _selectedIcons[i]),
              label: _labels[i],
              tooltip: i == 2 && pending > 0
                  ? 'Alertas, $pending pendentes de análise'
                  : _labels[i],
            ),
        ],
      ),
    );
  }
}

/// Ação de ajustes repetida na barra superior das telas principais.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Abrir ajustes',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.pushNamed(Routes.settings),
  );
}
