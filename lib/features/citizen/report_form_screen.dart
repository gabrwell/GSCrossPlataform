import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../../domain/validators.dart';
import '../../shared/common_widgets.dart';
import '../../state/reports_controller.dart';
import '../../state/territory_controller.dart';

/// Formulário de relato: não pede nome nem contato e barra dados pessoais no
/// texto livre.
class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  late String _territoryId = context.read<TerritoryController>().selected.id;
  ReportCategory? _category;
  int _urgency = 2;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    await context.read<ReportsController>().add(
          territoryId: _territoryId,
          category: _category!,
          description: _description.text,
          urgency: _urgency,
        );
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Relato salvo de forma anônima. Obrigado!')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo relato')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            const Text('Não pedimos nome nem contato. A data é guardada sem '
                'horário para dificultar a identificação.'),
            DropdownButtonFormField<String>(
              initialValue: _territoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bairro'),
              items: [
                for (final t in kTerritories)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (id) {
                if (id != null) setState(() => _territoryId = id);
              },
            ),
            DropdownButtonFormField<ReportCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de ocorrência'),
              validator: (value) =>
                  value == null ? 'Escolha o tipo de ocorrência.' : null,
              items: [
                for (final c in ReportCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 280,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: Validators.reportDescription,
              decoration: const InputDecoration(
                labelText: 'O que está acontecendo?',
                helperText: 'Não inclua nomes, telefones, e-mails ou documentos.',
                alignLabelWithHint: true,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Urgência'),
                const SizedBox(height: Gap.sm),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Baixa')),
                    ButtonSegment(value: 2, label: Text('Média')),
                    ButtonSegment(value: 3, label: Text('Alta')),
                  ],
                  selected: {_urgency},
                  onSelectionChanged: (value) =>
                      setState(() => _urgency = value.first),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send),
              label: const Text('Salvar relato'),
            ),
          ],
        ),
      ),
    );
  }
}
