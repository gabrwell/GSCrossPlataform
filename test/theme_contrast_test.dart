import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/core/app_theme.dart';

/// Garante contraste WCAG AA (4,5:1) nas cores usadas para comunicar estado.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final themes = {
    'claro': AppTheme.light,
    'escuro': AppTheme.dark,
    'alto contraste': AppTheme.highContrast,
  };

  themes.forEach((name, theme) {
    test('tema $name atende ao contraste mínimo', () {
      final semantic = theme.extension<SemanticColors>()!;
      for (final pair in [
        semantic.critical,
        semantic.attention,
        semantic.info,
        semantic.positive,
      ]) {
        expect(
          contrast(pair.background, pair.foreground),
          greaterThanOrEqualTo(4.5),
        );
      }
      final scheme = theme.colorScheme;
      expect(
        contrast(scheme.surface, scheme.onSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.surface, scheme.onSurfaceVariant),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
