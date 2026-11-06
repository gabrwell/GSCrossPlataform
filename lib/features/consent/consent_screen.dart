import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../shared/common_widgets.dart';
import '../../state/settings_controller.dart';

/// Etapa inicial: apresenta o app e pede consentimento explícito. Quem recusa
/// continua usando os painéis; só o registro de relatos fica desativado.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsController>();
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          children: [
            const SizedBox(height: Gap.md),
            ExcludeSemantics(
              child: Icon(
                Icons.hub_outlined,
                size: 56,
                color: context.colors.primary,
              ),
            ),
            Semantics(
              header: true,
              child: Text('Território Vivo', style: context.text.headlineSmall),
            ),
            const Text(
              'Indicadores, previsões e alertas para antecipar '
              'problemas do bairro, sempre com a decisão nas mãos de pessoas.',
            ),
            const HumanDecisionNotice(),
            const SectionTitle('Como tratamos seus dados'),
            const BulletList(
              icon: Icons.lock_outline,
              items: [
                'Não coletamos nome, e-mail, telefone nem localização precisa.',
                'Relatos são anônimos, ficam só neste aparelho e a data é '
                    'guardada sem horário.',
                'Textos com e-mail, telefone ou CPF são recusados no formulário.',
                'Você pode retirar o consentimento e apagar tudo nos Ajustes.',
              ],
            ),
            Card(
              child: CheckboxListTile(
                value: _accepted,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                title: const Text(
                  'Concordo em registrar relatos anônimos conforme descrito acima.',
                ),
              ),
            ),
            FilledButton(
              onPressed: _accepted
                  ? () => settings.completeOnboarding(consent: true)
                  : null,
              child: const Text('Concordar e continuar'),
            ),
            OutlinedButton(
              onPressed: () => settings.completeOnboarding(consent: false),
              child: const Text('Continuar sem registrar relatos'),
            ),
          ],
        ),
      ),
    );
  }
}
