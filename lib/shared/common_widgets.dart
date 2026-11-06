import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../domain/catalog.dart';
import '../domain/formatters.dart';
import '../domain/models.dart';
import '../state/territory_controller.dart';

/// Corpo padrão de tela: largura máxima, margem e rolagem.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl * 2),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (_, index) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Gap.contentMaxWidth),
          child: SizedBox(width: double.infinity, child: children[index]),
        ),
      ),
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: context.text.titleMedium),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

/// Grade que ajusta o número de colunas à largura disponível.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 300,
  });

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minItemWidth).floor().clamp(1, 4);
        final itemWidth = (width - (columns - 1) * Gap.md) / columns;
        return Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Etiqueta colorida que sempre combina cor, ícone e texto.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.colors,
    this.icon,
  });

  final String label;
  final ColorPair colors;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.sm + 2,
        vertical: Gap.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.foreground, width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.foreground),
            const SizedBox(width: Gap.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key});

  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: severity.label,
      colors: context.semantic.severity(severity),
      icon: switch (severity) {
        AlertSeverity.critico => Icons.error,
        AlertSeverity.atencao => Icons.warning_amber,
        AlertSeverity.informativo => Icons.info_outline,
      },
    );
  }
}

class OriginTag extends StatelessWidget {
  const OriginTag(this.origin, {super.key});

  final DataOrigin origin;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: origin.label,
      colors: origin == DataOrigin.real
          ? context.semantic.positive
          : context.semantic.info,
      icon: origin == DataOrigin.real ? Icons.public : Icons.science_outlined,
    );
  }
}

/// Barra de confiança animada, com rótulo textual e descrição para leitor de tela.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter(this.score, {super.key});

  final double score;

  @override
  Widget build(BuildContext context) {
    final level = ConfidenceLevel.fromScore(score);
    final pair = context.semantic.confidence(level);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Nível de confiança ${level.label}, ${formatPercent(score)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Confiança: ${level.label}',
                  style: context.text.labelLarge,
                ),
              ),
              Text(formatPercent(score), style: context.text.labelLarge),
            ],
          ),
          const SizedBox(height: Gap.xs),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                color: pair.foreground,
                backgroundColor: context.colors.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso obrigatório: os alertas apoiam, mas não substituem, a decisão humana.
class HumanDecisionNotice extends StatelessWidget {
  const HumanDecisionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final pair = context.semantic.info;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.md - 4),
        decoration: BoxDecoration(
          color: pair.background,
          borderRadius: BorderRadius.circular(Gap.radius),
          border: Border.all(color: pair.foreground, width: 0.75),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.how_to_reg, color: pair.foreground),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Os alertas apoiam, mas não substituem, a decisão humana. '
                'Nenhuma ação é executada automaticamente pelo app.',
                style: context.text.bodyMedium?.copyWith(
                  color: pair.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avisa quando os dados de clima vêm do cache porque não há conexão.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<TerritoryController>().snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    if (!snapshot.climateFromCache && !snapshot.climateUnavailable) {
      return const SizedBox.shrink();
    }
    final pair = context.semantic.attention;
    final fetched = snapshot.climateFetchedAt;
    final message = snapshot.climateUnavailable
        ? 'Sem conexão e sem clima salvo. Os demais painéis seguem funcionando.'
        : 'Sem conexão. Clima salvo em '
              '${fetched == null ? '-' : formatDateTime(fetched)}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(Gap.sm + 4),
          decoration: BoxDecoration(
            color: pair.background,
            borderRadius: BorderRadius.circular(Gap.radius / 1.5),
            border: Border.all(color: pair.foreground, width: 0.75),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: pair.foreground),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodyMedium?.copyWith(
                    color: pair.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TerritorySelector extends StatelessWidget {
  const TerritorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TerritoryController>();
    return DropdownButtonFormField<String>(
      key: ValueKey(controller.selected.id),
      initialValue: controller.selected.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Bairro acompanhado',
        prefixIcon: Icon(Icons.place_outlined),
      ),
      items: [
        for (final t in kTerritories)
          DropdownMenuItem(value: t.id, child: Text('${t.name} · ${t.zone}')),
      ],
      onChanged: (id) {
        if (id != null) controller.select(id);
      },
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Carregando dados do bairro…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Gap.md),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.colors.primary),
          const SizedBox(height: Gap.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: Gap.xs),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: Gap.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Lista com marcador, usada para evidências e limitações.
class BulletList extends StatelessWidget {
  const BulletList({super.key, required this.items, required this.icon});

  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: 18, color: context.colors.primary),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.note,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: context.colors.primary)),
            const SizedBox(height: Gap.sm),
            Text(value, style: context.text.headlineSmall),
            Text(label, style: context.text.bodyMedium),
            if (note != null) ...[
              const SizedBox(height: Gap.xs),
              Text(
                note!,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
