import 'models.dart';

/// Bairros monitorados. Populações são aproximadas e os fatores definem o
/// perfil sintético de cada um (não são medições reais).
const List<Territory> kTerritories = [
  Territory(
    id: 'capao-redondo',
    name: 'Capão Redondo',
    zone: 'Zona Sul',
    latitude: -23.6653,
    longitude: -46.7700,
    population: 275000,
    waterFactor: 1.04,
    energyFactor: 0.92,
    wasteFactor: 1.08,
    serviceFactor: 1.24,
    reservoirBase: 46,
  ),
  Territory(
    id: 'se',
    name: 'Sé',
    zone: 'Centro',
    latitude: -23.5503,
    longitude: -46.6339,
    population: 24000,
    waterFactor: 1.14,
    energyFactor: 1.18,
    wasteFactor: 1.2,
    serviceFactor: 0.92,
    reservoirBase: 62,
  ),
  Territory(
    id: 'itaim-paulista',
    name: 'Itaim Paulista',
    zone: 'Zona Leste',
    latitude: -23.5014,
    longitude: -46.3995,
    population: 224000,
    waterFactor: 0.98,
    energyFactor: 0.88,
    wasteFactor: 1.02,
    serviceFactor: 1.3,
    reservoirBase: 41,
  ),
  Territory(
    id: 'lapa',
    name: 'Lapa',
    zone: 'Zona Oeste',
    latitude: -23.5275,
    longitude: -46.7042,
    population: 65000,
    waterFactor: 1.0,
    energyFactor: 1.08,
    wasteFactor: 0.94,
    serviceFactor: 0.82,
    reservoirBase: 68,
  ),
];

Territory territoryById(String id) =>
    kTerritories.firstWhere((t) => t.id == id, orElse: () => kTerritories.first);

const List<IndicatorDefinition> kIndicators = [
  // Recursos (sintéticos)
  IndicatorDefinition(
    id: 'agua',
    name: 'Consumo de água',
    shortName: 'Água',
    unit: 'L/hab/dia',
    dashboard: DashboardKind.recursos,
    origin: DataOrigin.sintetico,
    description:
        'Consumo médio diário de água por habitante. Picos podem indicar '
        'vazamentos ou desperdício.',
    defaultThreshold: 175,
    minThreshold: 80,
    maxThreshold: 300,
    decimals: 0,
    humanAction:
        'Avaliar com a concessionária se há vazamentos e se cabe uma campanha '
        'de uso consciente.',
  ),
  IndicatorDefinition(
    id: 'energia',
    name: 'Consumo de energia',
    shortName: 'Energia',
    unit: 'kWh/hab/dia',
    dashboard: DashboardKind.recursos,
    origin: DataOrigin.sintetico,
    description: 'Consumo médio diário de energia elétrica por habitante.',
    defaultThreshold: 6.2,
    minThreshold: 2,
    maxThreshold: 15,
    humanAction:
        'Verificar com a distribuidora o risco de sobrecarga na rede local.',
  ),
  IndicatorDefinition(
    id: 'residuos',
    name: 'Resíduos gerados',
    shortName: 'Resíduos',
    unit: 'kg/hab/dia',
    dashboard: DashboardKind.recursos,
    origin: DataOrigin.sintetico,
    description: 'Massa de resíduos coletada por habitante a cada dia.',
    defaultThreshold: 1.35,
    minThreshold: 0.5,
    maxThreshold: 3,
    decimals: 2,
    useBars: true,
    humanAction:
        'Analisar o reforço da coleta e a existência de pontos de descarte '
        'irregular.',
  ),
  IndicatorDefinition(
    id: 'reservatorio',
    name: 'Nível do reservatório local',
    shortName: 'Reservatório',
    unit: '%',
    dashboard: DashboardKind.recursos,
    origin: DataOrigin.sintetico,
    description:
        'Nível do reservatório que abastece a região. Aqui o risco está em '
        'ficar abaixo do limiar.',
    defaultThreshold: 40,
    minThreshold: 10,
    maxThreshold: 80,
    decimals: 0,
    direction: RiskDirection.below,
    humanAction:
        'Discutir com a concessionária medidas de contingência, priorizando '
        'serviços essenciais.',
  ),
  // Clima (dados reais da Open-Meteo)
  IndicatorDefinition(
    id: 'temperatura',
    name: 'Temperatura máxima',
    shortName: 'Temperatura',
    unit: '°C',
    dashboard: DashboardKind.clima,
    origin: DataOrigin.real,
    description: 'Temperatura máxima diária. Calor extremo afeta idosos, '
        'crianças e pessoas em moradias precárias.',
    defaultThreshold: 33,
    minThreshold: 20,
    maxThreshold: 45,
    humanAction:
        'Avaliar a abertura de pontos de hidratação e o aviso a unidades de '
        'saúde.',
  ),
  IndicatorDefinition(
    id: 'chuva',
    name: 'Precipitação diária',
    shortName: 'Chuva',
    unit: 'mm',
    dashboard: DashboardKind.clima,
    origin: DataOrigin.real,
    description:
        'Chuva acumulada no dia. Volumes altos elevam o risco de alagamento.',
    defaultThreshold: 30,
    minThreshold: 5,
    maxThreshold: 150,
    detectAnomaly: false,
    useBars: true,
    humanAction:
        'Acionar a análise da Defesa Civil sobre áreas sujeitas a alagamento.',
  ),
  IndicatorDefinition(
    id: 'ar',
    name: 'Qualidade do ar',
    shortName: 'Ar (IQA)',
    unit: 'IQA',
    dashboard: DashboardKind.clima,
    origin: DataOrigin.real,
    description: 'Índice de qualidade do ar (escala US AQI, média diária). '
        'Acima de 100 já há risco para grupos sensíveis.',
    defaultThreshold: 100,
    minThreshold: 20,
    maxThreshold: 300,
    decimals: 0,
    humanAction:
        'Avaliar a orientação à população sensível e a checagem em estações '
        'oficiais de medição.',
  ),
  // Serviços (sintéticos)
  IndicatorDefinition(
    id: 'atendimentos',
    name: 'Demanda em UBS',
    shortName: 'Demanda UBS',
    unit: 'atend./10 mil hab',
    dashboard: DashboardKind.servicos,
    origin: DataOrigin.sintetico,
    description: 'Atendimentos diários em Unidades Básicas de Saúde para cada '
        '10 mil habitantes.',
    defaultThreshold: 40,
    minThreshold: 10,
    maxThreshold: 100,
    decimals: 0,
    humanAction: 'Avaliar reforço temporário de equipes nas UBS da região.',
  ),
  IndicatorDefinition(
    id: 'zeladoria',
    name: 'Solicitações de zeladoria',
    shortName: 'Zeladoria',
    unit: 'pedidos/10 mil hab',
    dashboard: DashboardKind.servicos,
    origin: DataOrigin.sintetico,
    description: 'Pedidos diários de reparo urbano para cada 10 mil habitantes.',
    defaultThreshold: 8.5,
    minThreshold: 2,
    maxThreshold: 30,
    useBars: true,
    humanAction: 'Analisar a redistribuição de equipes de manutenção urbana.',
  ),
  IndicatorDefinition(
    id: 'espera',
    name: 'Espera por consulta',
    shortName: 'Espera',
    unit: 'dias',
    dashboard: DashboardKind.servicos,
    origin: DataOrigin.sintetico,
    description: 'Tempo médio de espera por uma consulta eletiva.',
    defaultThreshold: 14,
    minThreshold: 3,
    maxThreshold: 60,
    humanAction: 'Avaliar mutirões e a revisão de prioridades da fila.',
  ),
];

IndicatorDefinition indicatorById(String id) =>
    kIndicators.firstWhere((i) => i.id == id);

List<IndicatorDefinition> indicatorsFor(DashboardKind kind) =>
    kIndicators.where((i) => i.dashboard == kind).toList();

Map<String, double> defaultThresholds() =>
    {for (final i in kIndicators) i.id: i.defaultThreshold};
