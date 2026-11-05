import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/app_theme.dart';
import '../../data/explanation_service.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../../domain/validators.dart';
import '../../shared/common_widgets.dart';
import '../../state/alerts_controller.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context) {
    final alert = context.watch<AlertsController>().byId(alertId);
    return Scaffold(
      appBar: AppBar(title: const Text('Justificativa do alerta')),
      body: alert == null
          ? const Center(
              child: MessageView(
                icon: Icons.history,
                title: 'Este alerta não está mais ativo',
                message: 'Os dados ou os limiares mudaram desde que ele foi '
                    'gerado. Sua decisão, se houver, continua salva.',
              ),
            )
          : PageBody(
              children: [
                _Header(alert: alert),
                _Section(
                  title: 'Por que este alerta existe',
                  icon: Icons.fact_check_outlined,
                  child: BulletList(
                    items: alert.evidence,
                    icon: Icons.chevron_right,
                  ),
                ),
                _Section(
                  title: 'Nível de confiança',
                  icon: Icons.speed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConfidenceMeter(alert.confidence),
                      if (!alert.reliable) ...[
                        const SizedBox(height: Gap.sm),
                        const Text('Sinal de baixa confiabilidade: confirme em '
                            'outras fontes antes de tirar conclusões.'),
                      ],
                    ],
                  ),
                ),
                _Section(
                  title: 'Limitações',
                  icon: Icons.report_problem_outlined,
                  child: BulletList(
                    items: alert.limitations,
                    icon: Icons.chevron_right,
                  ),
                ),
                _ExplanationCard(alert: alert),
                _Section(
                  title: 'O que uma pessoa pode avaliar',
                  icon: Icons.lightbulb_outline,
                  child: Text(alert.humanAction),
                ),
                const HumanDecisionNotice(),
                _DecisionForm(alert: alert),
                if (alert.indicatorId != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.insights),
                    label: const Text('Ver dados do indicador'),
                    onPressed: () => context.pushNamed(
                      Routes.indicator,
                      pathParameters: {'indicatorId': alert.indicatorId!},
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.alert});

  final TerritoryAlert alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.xs,
          children: [
            SeverityBadge(alert.severity),
            StatusPill(
              label: alert.kind.label,
              colors: context.semantic.info,
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Semantics(
          header: true,
          child: Text(alert.title, style: context.text.headlineSmall),
        ),
        const SizedBox(height: Gap.xs),
        Text(alert.summary, style: context.text.bodyLarge),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: context.colors.primary),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: context.text.titleSmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatefulWidget {
  const _ExplanationCard({required this.alert});

  final TerritoryAlert alert;

  @override
  State<_ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<_ExplanationCard> {
  bool _loading = false;
  AlertExplanation? _explanation;

  Future<void> _explain() async {
    setState(() => _loading = true);
    final result =
        await context.read<ExplanationService>().explain(widget.alert);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _explanation = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final explanation = _explanation;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Section(
      title: 'Em linguagem simples',
      icon: Icons.record_voice_over_outlined,
      child: AnimatedSize(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const LoadingView(message: 'Preparando a explicação…')
            else if (explanation == null)
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Explicar este alerta'),
                onPressed: _explain,
              )
            else ...[
              Semantics(liveRegion: true, child: Text(explanation.text)),
              const SizedBox(height: Gap.sm),
              Text(
                explanation.generatedByAi
                    ? 'Texto gerado por IA generativa a partir dos dados do '
                        'alerta. Pode conter imprecisões.'
                    : 'Texto automático montado a partir dos dados do alerta.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Registro da decisão humana. Fica apenas no aparelho e não dispara nada.
class _DecisionForm extends StatefulWidget {
  const _DecisionForm({required this.alert});

  final TerritoryAlert alert;

  @override
  State<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends State<_DecisionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _note;
  late DecisionStatus _status;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AlertsController>().decisions[widget.alert.id];
    _status = saved?.status ?? DecisionStatus.pendente;
    _note = TextEditingController(text: saved?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    await context
        .read<AlertsController>()
        .decide(widget.alert.id, _status, _note.text);
    messenger.showSnackBar(
      SnackBar(content: Text('Registrado: ${_status.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.select<AlertsController, AlertDecision?>(
      (c) => c.decisions[widget.alert.id],
    );
    return _Section(
      title: 'Sua decisão',
      icon: Icons.how_to_reg_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<DecisionStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Situação do alerta'),
              items: [
                for (final status in DecisionStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 280,
              validator: Validators.decisionNote,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                helperText: 'Não inclua nomes, telefones ou documentos.',
              ),
            ),
            const SizedBox(height: Gap.sm),
            FilledButton(
              onPressed: _save,
              child: const Text('Registrar decisão'),
            ),
            if (saved != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Último registro em ${formatDateTime(saved.decidedAt)}.',
                style: context.text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
