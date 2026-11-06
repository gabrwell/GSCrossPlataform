import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/app_theme.dart';
import '../../domain/alert_engine.dart';
import '../../domain/catalog.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../../shared/common_widgets.dart';
import '../../state/reports_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/territory_controller.dart';
import '../shell/app_shell.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final territory = context.watch<TerritoryController>().selected;
    final reports = context.watch<ReportsController>().forTerritory(
      territory.id,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatos do cidadão'),
        actions: const [SettingsAction()],
      ),
      floatingActionButton: settings.reportConsent
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(Routes.reportForm),
              icon: const Icon(Icons.add),
              label: const Text('Novo relato'),
            )
          : null,
      body: PageBody(
        children: [
          const TerritorySelector(),
          const SectionTitle(
            'Sua observação ajuda o bairro',
            subtitle:
                'Relatos são anônimos e ficam só neste aparelho. '
                '${AlertEngine.clusterMinReports} relatos parecidos em 7 dias '
                'geram um sinal para análise humana.',
          ),
          if (!settings.reportConsent)
            Card(
              child: MessageView(
                icon: Icons.privacy_tip_outlined,
                title: 'Consentimento necessário',
                message:
                    'Para registrar relatos, é preciso concordar com o uso '
                    'anônimo das informações. O restante do app funciona sem isso.',
                actionLabel: 'Concordar e habilitar relatos',
                onAction: () => settings.setConsent(true),
              ),
            ),
          if (reports.isEmpty)
            const MessageView(
              icon: Icons.inbox_outlined,
              title: 'Nenhum relato neste bairro',
              message: 'Quando houver relatos, eles aparecem aqui.',
            )
          else
            for (final report in reports) _ReportCard(report: report),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final CitizenReport report;

  @override
  Widget build(BuildContext context) {
    final urgency = switch (report.urgency) {
      3 => ('Urgência alta', context.semantic.critical),
      2 => ('Urgência média', context.semantic.attention),
      _ => ('Urgência baixa', context.semantic.info),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.category.label,
                    style: context.text.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir este relato',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      context.read<ReportsController>().remove(report.id),
                ),
              ],
            ),
            Text(report.description),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(label: urgency.$1, colors: urgency.$2),
                Text(
                  '${territoryById(report.territoryId).name} · '
                  '${formatDay(report.day)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
