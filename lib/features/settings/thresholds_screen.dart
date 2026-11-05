import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../domain/catalog.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../../domain/validators.dart';
import '../../shared/common_widgets.dart';
import '../../state/settings_controller.dart';

/// Formulário de limiares. Ao salvar, os alertas são recalculados na hora.
class ThresholdsScreen extends StatefulWidget {
  const ThresholdsScreen({super.key, this.focusIndicatorId});

  /// Vindo do detalhe de um indicador, mostra apenas o campo dele.
  final String? focusIndicatorId;

  @override
  State<ThresholdsScreen> createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends State<ThresholdsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;

  List<IndicatorDefinition> get _visible => widget.focusIndicatorId == null
      ? kIndicators
      : [indicatorById(widget.focusIndicatorId!)];

  @override
  void initState() {
    super.initState();
    final thresholds = context.read<SettingsController>().thresholds;
    _fields = {
      for (final i in _visible)
        i.id: TextEditingController(
          text: formatNumber(thresholds[i.id]!, decimals: i.decimals),
        ),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await context.read<SettingsController>().saveThresholds({
      for (final entry in _fields.entries)
        entry.key: Validators.parseNumber(entry.value.text)!,
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Limiares salvos. Alertas recalculados.')),
    );
    if (router.canPop()) router.pop();
  }

  Future<void> _reset() async {
    final settings = context.read<SettingsController>();
    await settings.resetThresholds();
    for (final i in _visible) {
      _fields[i.id]!.text =
          formatNumber(i.defaultThreshold, decimals: i.decimals);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Limiares de alerta')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            const Text('O limiar é o valor a partir do qual o app sinaliza um '
                'alerta. Ele não dispara nenhuma ação automática.'),
            for (final kind in DashboardKind.values)
              if (_visible.any((i) => i.dashboard == kind))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(kind.label),
                    const SizedBox(height: Gap.sm),
                    for (final i in _visible.where((i) => i.dashboard == kind))
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: TextFormField(
                          controller: _fields[i.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) => Validators.threshold(value, i),
                          decoration: InputDecoration(
                            labelText: i.name,
                            suffixText: i.unit,
                            helperText: i.direction == RiskDirection.above
                                ? 'Alerta quando passar deste valor'
                                : 'Alerta quando ficar abaixo deste valor',
                          ),
                        ),
                      ),
                  ],
                ),
            FilledButton(onPressed: _save, child: const Text('Salvar limiares')),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Restaurar valores padrão'),
            ),
          ],
        ),
      ),
    );
  }
}
