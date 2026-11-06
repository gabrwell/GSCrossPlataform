import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../../shared/common_widgets.dart';
import '../../state/alerts_controller.dart';
import '../../state/territory_controller.dart';
import '../shell/app_shell.dart';

/// Mapa dos bairros por nível de alerta. A lista repete a informação para quem
/// usa leitor de tela e continua útil quando os mapas não carregam offline.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  AlertSeverity? _worst(List<TerritoryAlert> alerts) =>
      alerts.isEmpty ? null : alerts.first.severity;

  ColorPair _pair(BuildContext context, AlertSeverity? severity) =>
      severity == null
      ? context.semantic.positive
      : context.semantic.severity(severity);

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    final alerts = context.watch<AlertsController>();
    final height = MediaQuery.sizeOf(context).height * 0.42;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de alertas'),
        actions: const [SettingsAction()],
      ),
      body: PageBody(
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Gap.radius),
              child: SizedBox(
                height: height,
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(-23.58, -46.60),
                    initialZoom: 10,
                    minZoom: 8,
                    maxZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'br.com.fiap.territorio_vivo',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final t in kTerritories)
                          Marker(
                            point: LatLng(t.latitude, t.longitude),
                            width: 56,
                            height: 56,
                            child: _Pin(
                              count: alerts.forTerritory(t.id).length,
                              pair: _pair(
                                context,
                                _worst(alerts.forTerritory(t.id)),
                              ),
                              selected: t.id == territory.selected.id,
                              onTap: () => territory.select(t.id),
                            ),
                          ),
                      ],
                    ),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SectionTitle(
            'Bairros',
            subtitle: 'Toque para acompanhar um bairro em todo o app',
          ),
          for (final t in kTerritories)
            _TerritoryRow(
              territory: t,
              alerts: alerts.forTerritory(t.id),
              selected: t.id == territory.selected.id,
              onTap: () => territory.select(t.id),
            ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.count,
    required this.pair,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final ColorPair pair;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: selected ? 48 : 40,
          height: selected ? 48 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pair.background,
            shape: BoxShape.circle,
            border: Border.all(color: pair.foreground, width: selected ? 4 : 2),
          ),
          child: Text(
            '$count',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: pair.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerritoryRow extends StatelessWidget {
  const _TerritoryRow({
    required this.territory,
    required this.alerts,
    required this.selected,
    required this.onTap,
  });

  final Territory territory;
  final List<TerritoryAlert> alerts;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worst = alerts.isEmpty ? null : alerts.first.severity;
    return Card(
      child: ListTile(
        selected: selected,
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
        ),
        title: Text(territory.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${territory.zone} · ${alerts.length} '
              '${alerts.length == 1 ? 'alerta' : 'alertas'}',
            ),
            if (worst != null) ...[
              const SizedBox(height: Gap.xs),
              SeverityBadge(worst),
            ],
          ],
        ),
      ),
    );
  }
}
