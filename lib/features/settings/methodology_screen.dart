import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../shared/common_widgets.dart';

class MethodologyScreen extends StatelessWidget {
  const MethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metodologia e limitações')),
      body: const PageBody(
        children: [
          _Block(
            title: 'Fontes de dados',
            items: [
              'Clima e qualidade do ar: dados reais e abertos da Open-Meteo, '
                  'estimados por modelos, sem sensores nos bairros.',
              'Água, energia, resíduos, reservatório e serviços: dados '
                  'sintéticos, gerados para demonstração. Não são medições reais.',
              'Relatos: informados por cidadãos, anônimos e não verificados.',
            ],
          ),
          _Block(
            title: 'Como os alertas são gerados',
            items: [
              'Limiar: o último valor já passou do limite configurado.',
              'Previsão: o valor previsto passa do limite em até 7 dias.',
              'Anomalia: o valor fica a 2,5 desvios-padrão ou mais da média '
                  'dos 28 dias anteriores.',
              'Relatos: 3 ou mais relatos da mesma categoria em 7 dias.',
            ],
          ),
          _Block(
            title: 'Métricas',
            items: [
              'Previsão: regressão linear com ajuste por dia da semana, '
                  'treinada com os últimos 28 dias.',
              'MAPE: erro percentual médio no teste com os últimos 7 dias '
                  'deixados de fora do treino.',
              'Confiança: cai com o erro do teste e com a distância da previsão.',
              'Severidade: crítica a partir de 15% além do limiar; atenção a '
                  'partir de 5%.',
            ],
          ),
          _Block(
            title: 'Quando não confiar nas previsões',
            items: [
              'Histórico com menos de 14 dias, último dado com mais de 3 dias '
                  'ou erro no teste (MAPE) acima de 25%: o app detecta esses '
                  'casos, marca o alerta e não deixa chegar ao nível crítico.',
              'Eventos sem precedente nos dados, como obras, rompimentos, '
                  'greves ou mudanças bruscas de clima: o app não consegue '
                  'detectar esses casos, então cabe às pessoas considerá-los.',
            ],
          ),
          _Block(
            title: 'Possíveis vieses',
            items: [
              'Relatos digitais sub-representam quem tem menos acesso à internet, '
                  'muitas vezes justamente os mais vulneráveis.',
              'Dados climáticos cobrem áreas de cerca de 10 km e podem esconder '
                  'diferenças entre ruas e comunidades.',
              'Limiares iguais para bairros diferentes podem não refletir as '
                  'necessidades de cada lugar.',
            ],
          ),
          _Block(
            title: 'Papel das pessoas',
            items: [
              'O app só sinaliza. Nenhuma ação é executada automaticamente.',
              'A decisão registrada em cada alerta fica no aparelho e é de '
                  'responsabilidade de quem decidiu.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.text.titleSmall),
            ),
            const SizedBox(height: Gap.sm),
            BulletList(items: items, icon: Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
