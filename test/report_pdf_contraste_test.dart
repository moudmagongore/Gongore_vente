import 'package:flutter_test/flutter_test.dart';
import 'package:gongore_vente/app/core/services/report_pdf_service.dart';
import 'package:pdf/pdf.dart';

/// Lisibilité des encadrés d'indicateurs du rapport PDF.
///
/// Le défaut d'origine venait de `PdfColor.shade(x)`, qui multiplie la
/// luminosité par `1.5 - x` : `shade(0.92)` ASSOMBRIT à 58 % au lieu
/// d'éclaircir. Les encadrés sortaient en couleurs saturées, sur
/// lesquelles le libellé gris et la valeur — de la teinte même du fond —
/// devenaient illisibles.
///
/// Ces tests figent la règle : fond clair, texte sombre, pour **toutes**
/// les couleurs employées par le rapport.
void main() {
  const couleursDuRapport = <String, PdfColor>{
    'blue': PdfColors.blue,
    'green': PdfColors.green,
    'indigo': PdfColors.indigo,
    'purple': PdfColors.purple,
    'red': PdfColors.red,
    'orange': PdfColors.orange,
    'teal': PdfColors.teal,
    'amber': PdfColors.amber,
  };

  group('fond des encadrés', () {
    couleursDuRapport.forEach((nom, couleur) {
      test('$nom donne un fond clair', () {
        final fond = ReportPdfService.fondPale(couleur, 0.94).toHsl();
        expect(fond.lightness, greaterThan(0.9),
            reason: 'un fond sombre rendrait le texte illisible');
      });
    });
  });

  group('couleur des valeurs', () {
    couleursDuRapport.forEach((nom, couleur) {
      test('$nom donne un texte sombre', () {
        final texte = ReportPdfService.texteLisible(couleur).toHsl();
        expect(texte.lightness, lessThanOrEqualTo(0.42),
            reason: 'une valeur claire disparaîtrait sur le fond pâle');
      });
    });
  });

  group('écart entre le fond et le texte', () {
    couleursDuRapport.forEach((nom, couleur) {
      test('$nom : contraste suffisant', () {
        final fond = ReportPdfService.fondPale(couleur, 0.94).toHsl();
        final texte = ReportPdfService.texteLisible(couleur).toHsl();
        expect(fond.lightness - texte.lightness, greaterThan(0.45),
            reason: 'c\'est cet écart qui manquait avant correction');
      });
    });
  });

  test('la teinte est conservee : l encadre reste reconnaissable', () {
    final source = PdfColors.indigo.toHsl();
    final fond = ReportPdfService.fondPale(PdfColors.indigo, 0.94).toHsl();
    expect(fond.hue, closeTo(source.hue, 0.01));
  });

  test('une couleur deja sombre n est pas eclaircie par texteLisible', () {
    // Garde-fou : la fonction plafonne, elle ne doit pas remonter la
    // luminosité d'un bleu nuit déjà parfaitement lisible.
    final sombre = PdfColorHsl(0.6, 0.8, 0.2);
    expect(ReportPdfService.texteLisible(sombre).toHsl().lightness,
        closeTo(0.2, 0.001));
  });
}
