import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Charge et met en cache les variantes NunitoSans pour les reçus PDF.
/// Tous les services de reçus passent par [pdfTheme] pour récupérer un
/// `pw.ThemeData` déjà configuré avec NunitoSans.
class PdfThemeService {
  PdfThemeService._();

  static pw.ThemeData? _cached;

  /// Renvoie un thème PDF utilisant NunitoSans (regular / bold / italic /
  /// boldItalic). Le résultat est mis en cache après le premier chargement.
  static Future<pw.ThemeData> get theme async {
    if (_cached != null) return _cached!;

    final regular = await _load('assets/fonts/NunitoSans-Regular.ttf');
    final bold = await _load('assets/fonts/NunitoSans-Bold.ttf');
    final italic = await _load('assets/fonts/NunitoSans-Italic.ttf');
    final boldItalic =
        await _load('assets/fonts/NunitoSans-BoldItalic.ttf');

    _cached = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
    return _cached!;
  }

  static Future<pw.Font> _load(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }
}
