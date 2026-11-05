import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';

class AlertExplanation {
  const AlertExplanation(this.text, {required this.generatedByAi});
  final String text;
  final bool generatedByAi;
}

/// Explica um alerta em linguagem simples. Com chave de API usa IA generativa;
/// sem chave, ou em caso de falha, usa um texto montado a partir do alerta.
///
/// Só dados agregados do alerta são enviados. Relatos de cidadãos nunca são.
class ExplanationService {
  ExplanationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const String _model = 'claude-opus-5-5';

  bool get aiEnabled => _apiKey.isNotEmpty;

  Future<AlertExplanation> explain(TerritoryAlert alert) async {
    if (!aiEnabled) return AlertExplanation(template(alert), generatedByAi: false);
    try {
      final text = await _askClaude(alert);
      if (text != null) return AlertExplanation(text, generatedByAi: true);
    } catch (error) {
      debugPrint('Explicação por IA indisponível: ${error.runtimeType}');
    }
    return AlertExplanation(template(alert), generatedByAi: false);
  }

  Future<String?> _askClaude(TerritoryAlert alert) async {
    final response = await _client
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2026-10-21',
            'anthropic-beta': 'server-side-fallback-2026-07-01',
            if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': 2000,
            'output_config': {'effort': 'low'},
            'fallbacks': 'default',
            'system': 'Você explica alertas de um painel público para moradores '
                'de um bairro. Escreva em português do Brasil, em até 4 frases '
                'curtas e sem termos técnicos. Use apenas os dados recebidos, '
                'mantenha a incerteza visível e lembre que uma pessoa responsável '
                'decide o que fazer. Não dê ordens nem orientação médica.',
            'messages': [
              {'role': 'user', 'content': _prompt(alert)},
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) return null;
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['stop_reason'] == 'refusal') return null;
    final text = (json['content'] as List)
        .cast<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String)
        .join('\n')
        .trim();
    return text.isEmpty ? null : text;
  }

  String _prompt(TerritoryAlert alert) => 'Alerta: ${alert.title}\n'
      'Resumo: ${alert.summary}\n'
      'Severidade: ${alert.severity.label}\n'
      'Confiança: ${alert.confidenceLevel.label}\n'
      'Evidências:\n- ${alert.evidence.join('\n- ')}\n'
      'Limitações:\n- ${alert.limitations.join('\n- ')}';

  static String template(TerritoryAlert alert) {
    final certainty = switch (alert.confidenceLevel) {
      ConfidenceLevel.alta => 'Os dados dão boa segurança a esse sinal',
      ConfidenceLevel.media => 'Esse sinal é razoável, mas pode não se confirmar',
      ConfidenceLevel.baixa => 'Esse sinal é fraco e pode estar errado',
    };
    final timing = alert.leadDays == 0
        ? 'Isso já aparece nos dados mais recentes.'
        : 'Isso pode acontecer em cerca de ${alert.leadDays} '
            '${alert.leadDays == 1 ? 'dia' : 'dias'}.';
    return '${alert.summary} $timing $certainty. O app não toma nenhuma '
        'providência sozinho: quem decide é uma pessoa responsável.';
  }
}
