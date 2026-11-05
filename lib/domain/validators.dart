import 'models.dart';

/// Validações de formulário. Ficam fora dos widgets para serem testáveis.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final RegExp _cpf = RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b');
  static final RegExp _phone = RegExp(r'(\(?\d{2}\)?[\s-]?)?\b9?\d{4}[\s-]?\d{4}\b');

  /// Detecta dados pessoais em texto livre, para proteger quem relata.
  static bool containsPersonalData(String text) =>
      _email.hasMatch(text) || _cpf.hasMatch(text) || _phone.hasMatch(text);

  static String? reportDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Descreva a ocorrência.';
    if (text.length < 15) {
      return 'Escreva pelo menos 15 caracteres para o relato ser útil.';
    }
    if (text.length > 280) return 'Use no máximo 280 caracteres.';
    if (containsPersonalData(text)) {
      return 'Remova e-mail, telefone ou CPF: o relato deve ser anônimo.';
    }
    return null;
  }

  static String? decisionNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 280) return 'Use no máximo 280 caracteres.';
    if (containsPersonalData(text)) {
      return 'Remova e-mail, telefone ou CPF da observação.';
    }
    return null;
  }

  /// Aceita vírgula ou ponto decimal.
  static double? parseNumber(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  static String? threshold(String? value, IndicatorDefinition definition) {
    if ((value ?? '').trim().isEmpty) return 'Informe um valor.';
    final number = parseNumber(value);
    if (number == null) return 'Digite apenas números. Exemplo: 12,5.';
    if (number < definition.minThreshold || number > definition.maxThreshold) {
      return 'Use um valor entre ${_plain(definition.minThreshold)} e '
          '${_plain(definition.maxThreshold)} ${definition.unit}.';
    }
    return null;
  }

  static String _plain(double value) {
    final text =
        value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
    return text.replaceAll('.', ',');
  }
}
