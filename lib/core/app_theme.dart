import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Espaçamentos padronizados, usados em todas as telas.
class Gap {
  const Gap._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double radius = 16;
  static const double contentMaxWidth = 1040;
}

class ColorPair {
  const ColorPair(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

/// Cores com significado (severidade e gráficos), definidas para cada tema.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.critical,
    required this.attention,
    required this.info,
    required this.positive,
    required this.history,
    required this.forecast,
    required this.threshold,
  });

  final ColorPair critical;
  final ColorPair attention;
  final ColorPair info;
  final ColorPair positive;
  final Color history;
  final Color forecast;
  final Color threshold;

  ColorPair severity(AlertSeverity value) => switch (value) {
    AlertSeverity.critico => critical,
    AlertSeverity.atencao => attention,
    AlertSeverity.informativo => info,
  };

  ColorPair confidence(ConfidenceLevel value) => switch (value) {
    ConfidenceLevel.alta => positive,
    ConfidenceLevel.media => attention,
    ConfidenceLevel.baixa => critical,
  };

  @override
  SemanticColors copyWith() => this;

  @override
  SemanticColors lerp(SemanticColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension ThemeShortcuts on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  SemanticColors get semantic => Theme.of(this).extension<SemanticColors>()!;
}

class AppTheme {
  const AppTheme._();

  static const SemanticColors lightSemantic = SemanticColors(
    critical: ColorPair(Color(0xFFFBE4E0), Color(0xFF8C1D18)),
    attention: ColorPair(Color(0xFFFFF0CC), Color(0xFF634400)),
    info: ColorPair(Color(0xFFDCEEF5), Color(0xFF0B4A63)),
    positive: ColorPair(Color(0xFFDDF2E3), Color(0xFF1B5E36)),
    history: Color(0xFF0B5D57),
    forecast: Color(0xFFA8431A),
    threshold: Color(0xFF8C1D18),
  );

  static const SemanticColors darkSemantic = SemanticColors(
    critical: ColorPair(Color(0xFF4A1512), Color(0xFFFFC9C2)),
    attention: ColorPair(Color(0xFF453300), Color(0xFFFFDF8F)),
    info: ColorPair(Color(0xFF0F3A4C), Color(0xFFB8E3F5)),
    positive: ColorPair(Color(0xFF123D25), Color(0xFFB2EBC6)),
    history: Color(0xFF6FD3C7),
    forecast: Color(0xFFFFB38F),
    threshold: Color(0xFFFFA69C),
  );

  static const SemanticColors contrastSemantic = SemanticColors(
    critical: ColorPair(Color(0xFF000000), Color(0xFFFF9A8F)),
    attention: ColorPair(Color(0xFF000000), Color(0xFFFFE600)),
    info: ColorPair(Color(0xFF000000), Color(0xFF8FE3FF)),
    positive: ColorPair(Color(0xFF000000), Color(0xFF8FFFB0)),
    history: Color(0xFFFFFFFF),
    forecast: Color(0xFFFFE600),
    threshold: Color(0xFFFF9A8F),
  );

  static ThemeData get light => _build(
    ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5D57),
      brightness: Brightness.light,
      primary: const Color(0xFF0B5D57),
      secondary: const Color(0xFFA8431A),
      surface: const Color(0xFFF7F5F0),
      onSurface: const Color(0xFF1C2321),
      onSurfaceVariant: const Color(0xFF47524F),
      surfaceContainerLow: const Color(0xFFFFFFFF),
    ),
    lightSemantic,
  );

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5D57),
      brightness: Brightness.dark,
      primary: const Color(0xFF6FD3C7),
      secondary: const Color(0xFFFFB38F),
      surface: const Color(0xFF111715),
      onSurface: const Color(0xFFE7ECEA),
      onSurfaceVariant: const Color(0xFFBCC7C3),
      surfaceContainerLow: const Color(0xFF1B2320),
    ),
    darkSemantic,
  );

  static ThemeData get highContrast => _build(
    const ColorScheme.highContrastDark(
      primary: Color(0xFFFFE600),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFF8FE3FF),
      onSecondary: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      error: Color(0xFFFF9A8F),
      onError: Color(0xFF000000),
    ).copyWith(
      onSurfaceVariant: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFF000000),
      outline: const Color(0xFFFFFFFF),
      outlineVariant: const Color(0xFFFFFFFF),
    ),
    contrastSemantic,
    outlinedCards: true,
  );

  static ThemeData _build(
    ColorScheme scheme,
    SemanticColors semantic, {
    bool outlinedCards = false,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Gap.radius),
      side: BorderSide(
        color: outlinedCards ? scheme.onSurface : scheme.outlineVariant,
        width: outlinedCards ? 1.5 : 0.75,
      ),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: shape,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Gap.radius / 2),
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
