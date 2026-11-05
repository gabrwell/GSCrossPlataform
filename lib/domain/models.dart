/// Modelos de domínio puros (sem dependência de Flutter), o que permite
/// testar a lógica de previsão e de alertas com testes de unidade simples.
library;

enum DashboardKind {
  recursos('Recursos'),
  clima('Clima'),
  servicos('Serviços');

  const DashboardKind(this.label);
  final String label;
}

enum DataOrigin {
  real('Dado real'),
  sintetico('Dado sintético');

  const DataOrigin(this.label);
  final String label;
}

/// Em qual sentido o valor do indicador representa risco.
enum RiskDirection { above, below }

class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.zone,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.waterFactor,
    required this.energyFactor,
    required this.wasteFactor,
    required this.serviceFactor,
    required this.reservoirBase,
  });

  final String id;
  final String name;
  final String zone;
  final double latitude;
  final double longitude;

  /// População aproximada, usada apenas para estimativas agregadas.
  final int population;

  /// Fatores que diferenciam os perfis sintéticos de cada bairro.
  final double waterFactor;
  final double energyFactor;
  final double wasteFactor;
  final double serviceFactor;
  final double reservoirBase;
}

class IndicatorDefinition {
  const IndicatorDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.dashboard,
    required this.origin,
    required this.description,
    required this.defaultThreshold,
    required this.minThreshold,
    required this.maxThreshold,
    required this.humanAction,
    this.decimals = 1,
    this.direction = RiskDirection.above,
    this.detectAnomaly = true,
    this.useBars = false,
  });

  final String id;
  final String name;
  final String shortName;
  final String unit;
  final DashboardKind dashboard;
  final DataOrigin origin;
  final String description;
  final double defaultThreshold;
  final double minThreshold;
  final double maxThreshold;

  /// O que uma pessoa gestora pode avaliar. Nunca é executado pelo app.
  final String humanAction;
  final int decimals;
  final RiskDirection direction;
  final bool detectAnomaly;
  final bool useBars;

  bool breaches(double value, double threshold) =>
      direction == RiskDirection.above ? value > threshold : value < threshold;
}

class DataPoint {
  const DataPoint(this.date, this.value);

  factory DataPoint.fromJson(Map<String, dynamic> json) => DataPoint(
        DateTime.parse(json['d'] as String),
        (json['v'] as num).toDouble(),
      );

  final DateTime date;
  final double value;

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String(),
        'v': value,
      };
}

/// Série de um indicador em um território.
class IndicatorSeries {
  const IndicatorSeries({
    required this.indicatorId,
    required this.history,
    required this.fetchedAt,
    this.externalForecast = const [],
  });

  factory IndicatorSeries.fromJson(Map<String, dynamic> json) =>
      IndicatorSeries(
        indicatorId: json['id'] as String,
        fetchedAt: DateTime.parse(json['at'] as String),
        history: (json['h'] as List)
            .map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        externalForecast: (json['f'] as List)
            .map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String indicatorId;
  final List<DataPoint> history;

  /// Previsão vinda da fonte externa (ex.: modelo meteorológico).
  /// Quando vazia, o app calcula a previsão com o próprio modelo estatístico.
  final List<DataPoint> externalForecast;
  final DateTime fetchedAt;

  double? get latest => history.isEmpty ? null : history.last.value;

  Map<String, dynamic> toJson() => {
        'id': indicatorId,
        'at': fetchedAt.toIso8601String(),
        'h': history.map((e) => e.toJson()).toList(),
        'f': externalForecast.map((e) => e.toJson()).toList(),
      };
}

/// Conjunto de dados de um território em um momento.
class TerritorySnapshot {
  const TerritorySnapshot({
    required this.territoryId,
    required this.series,
    required this.climateFromCache,
    required this.climateUnavailable,
  });

  final String territoryId;
  final Map<String, IndicatorSeries> series;

  /// O clima veio do cache local porque a API não respondeu.
  final bool climateFromCache;

  /// Não há clima nem na API nem no cache.
  final bool climateUnavailable;

  DateTime? get climateFetchedAt {
    for (final s in series.values) {
      if (s.externalForecast.isNotEmpty) return s.fetchedAt;
    }
    return null;
  }
}

enum ConfidenceLevel {
  alta('Alta'),
  media('Média'),
  baixa('Baixa');

  const ConfidenceLevel(this.label);
  final String label;

  static ConfidenceLevel fromScore(double score) {
    if (score >= 0.75) return ConfidenceLevel.alta;
    if (score >= 0.5) return ConfidenceLevel.media;
    return ConfidenceLevel.baixa;
  }
}

enum TrendDirection {
  rising('em alta'),
  stable('estável'),
  falling('em queda');

  const TrendDirection(this.label);
  final String label;
}

class ForecastPoint {
  const ForecastPoint({
    required this.date,
    required this.value,
    required this.lower,
    required this.upper,
  });

  final DateTime date;
  final double value;
  final double lower;
  final double upper;
}

class Forecast {
  const Forecast({
    required this.points,
    required this.method,
    required this.baseConfidence,
    required this.trend,
    required this.slopePerDay,
    required this.trainingDays,
    required this.mape,
    required this.unreliableReasons,
  });

  final List<ForecastPoint> points;
  final String method;

  /// Confiança de 0 a 1 antes do desconto pela distância da previsão.
  final double baseConfidence;
  final TrendDirection trend;
  final double slopePerDay;
  final int trainingDays;

  /// Erro percentual absoluto médio do backtest (0,12 = 12%).
  /// Nulo quando a previsão vem de fonte externa.
  final double? mape;

  /// Condições detectadas em que a previsão não deve ser considerada confiável.
  final List<String> unreliableReasons;

  bool get isReliable => unreliableReasons.isEmpty;

  /// A confiança cai conforme o horizonte da previsão se afasta.
  double confidenceAt(int leadDays) {
    final penalty = (leadDays - 1).clamp(0, 13) * 0.03;
    final score = baseConfidence - penalty;
    return score.clamp(0.05, 0.95).toDouble();
  }
}

enum AlertSeverity {
  informativo('Informativo'),
  atencao('Atenção'),
  critico('Crítico');

  const AlertSeverity(this.label);
  final String label;
}

enum AlertKind {
  previsao('Previsão'),
  observado('Limiar ultrapassado'),
  anomalia('Anomalia'),
  cidadao('Relatos de cidadãos');

  const AlertKind(this.label);
  final String label;
}

class TerritoryAlert {
  const TerritoryAlert({
    required this.id,
    required this.territoryId,
    required this.indicatorId,
    required this.kind,
    required this.severity,
    required this.title,
    required this.summary,
    required this.evidence,
    required this.confidence,
    required this.limitations,
    required this.humanAction,
    required this.leadDays,
    required this.reliable,
    required this.date,
  });

  final String id;
  final String territoryId;

  /// Nulo para alertas formados por relatos de cidadãos.
  final String? indicatorId;
  final AlertKind kind;
  final AlertSeverity severity;
  final String title;
  final String summary;
  final List<String> evidence;

  /// Confiança de 0 a 1.
  final double confidence;
  final List<String> limitations;
  final String humanAction;

  /// Quantos dias de antecedência o alerta oferece (0 = já observado).
  final int leadDays;
  final bool reliable;
  final DateTime date;

  ConfidenceLevel get confidenceLevel => ConfidenceLevel.fromScore(confidence);
}

/// Registro da decisão humana sobre um alerta.
enum DecisionStatus {
  pendente('Pendente de análise'),
  confirmado('Confirmado por pessoa'),
  descartado('Descartado por pessoa');

  const DecisionStatus(this.label);
  final String label;
}

class AlertDecision {
  const AlertDecision({
    required this.alertId,
    required this.status,
    required this.note,
    required this.decidedAt,
  });

  factory AlertDecision.fromJson(Map<String, dynamic> json) => AlertDecision(
        alertId: json['id'] as String,
        status: DecisionStatus.values.byName(json['status'] as String),
        note: json['note'] as String? ?? '',
        decidedAt: DateTime.parse(json['at'] as String),
      );

  final String alertId;
  final DecisionStatus status;
  final String note;
  final DateTime decidedAt;

  Map<String, dynamic> toJson() => {
        'id': alertId,
        'status': status.name,
        'note': note,
        'at': decidedAt.toIso8601String(),
      };
}

enum ReportCategory {
  agua('Vazamento ou falta de água'),
  energia('Falta de energia'),
  residuos('Lixo acumulado'),
  alagamento('Alagamento'),
  saude('Fila ou falta de atendimento'),
  outros('Outros');

  const ReportCategory(this.label);
  final String label;
}

/// Relato de ocorrência. Não guarda nome, contato nem coordenada exata, e a
/// data é truncada para o dia, reduzindo o risco de reidentificação.
class CitizenReport {
  const CitizenReport({
    required this.id,
    required this.territoryId,
    required this.category,
    required this.description,
    required this.urgency,
    required this.day,
  });

  factory CitizenReport.fromJson(Map<String, dynamic> json) => CitizenReport(
        id: json['id'] as String,
        territoryId: json['territory'] as String,
        category: ReportCategory.values.byName(json['category'] as String),
        description: json['description'] as String,
        urgency: json['urgency'] as int,
        day: DateTime.parse(json['day'] as String),
      );

  final String id;
  final String territoryId;
  final ReportCategory category;
  final String description;

  /// 1 (baixa), 2 (média) ou 3 (alta).
  final int urgency;
  final DateTime day;

  Map<String, dynamic> toJson() => {
        'id': id,
        'territory': territoryId,
        'category': category.name,
        'description': description,
        'urgency': urgency,
        'day': day.toIso8601String(),
      };
}
