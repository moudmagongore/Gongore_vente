import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/boutique_model.dart';
import '../../data/models/fournisseur_model.dart';
import '../../data/models/reglement_fournisseur_model.dart';
import '../../data/models/user_model.dart';
import '../utils/format_helpers.dart';
import '../utils/pdf_share_helper.dart';
import 'pdf_theme_service.dart';

/// Reçu PDF (format 80mm thermique) pour un règlement fournisseur.
class ReglementFournisseurReceiptService {
  static Future<Uint8List> build({
    required ReglementFournisseurModel reglement,
    required BoutiqueModel boutique,
    required FournisseurModel fournisseur,
    UserModel? user,
    double? soldeApres,
  }) async {
    final pdf = pw.Document(theme: await PdfThemeService.theme);
    final devise = boutique.devise;
    final numero = reglement.id.isEmpty
        ? '—'
        : 'RF-${reglement.id.substring(0, reglement.id.length < 6 ? reglement.id.length : 6).toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(
          marginTop: 8,
          marginBottom: 8,
          marginLeft: 8,
          marginRight: 8,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              boutique.nom.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (boutique.adresse?.isNotEmpty ?? false) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                boutique.adresse!,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
            if (boutique.telephone?.isNotEmpty ?? false) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'Tel : ${boutique.telephone}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Text(
              'REÇU FOURNISSEUR',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            _kv('N°', numero),
            _kv('Date', Fmt.dateTime(reglement.date)),
            _kv('Fournisseur', fournisseur.nom),
            if (fournisseur.telephone?.isNotEmpty ?? false)
              _kv('Téléphone', fournisseur.telephone!),
            _kv('Versé par', user?.nom ?? '—'),
            _kv('Mode', reglement.modePaiement.label),

            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MONTANT VERSÉ',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  Fmt.money(reglement.montant, currency: devise),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (reglement.imputations.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Imputations sur appros',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              ...reglement.imputations.map(
                (i) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        i.numero ??
                            (i.approId.isNotEmpty
                                ? i.approId.substring(
                                    0,
                                    i.approId.length < 8
                                        ? i.approId.length
                                        : 8,
                                  )
                                : '—'),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        Fmt.money(i.montant, currency: devise),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (reglement.surplus > 0) ...[
              pw.SizedBox(height: 4),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              _kv(
                'Avance versée',
                Fmt.money(reglement.surplus, currency: devise),
                bold: true,
              ),
            ],

            if (soldeApres != null) ...[
              pw.SizedBox(height: 4),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              _kv(
                soldeApres > 0
                    ? 'Reste à payer'
                    : (soldeApres < 0 ? 'Avance disponible' : 'Solde'),
                Fmt.money(soldeApres.abs(), currency: devise),
                bold: true,
              ),
            ],

            if (reglement.note?.isNotEmpty ?? false) ...[
              pw.SizedBox(height: 6),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note : ${reglement.note}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            ],

            pw.SizedBox(height: 12),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 8),
            pw.Text(
              'Reçu signé par le fournisseur',
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Container(
                width: 120, height: 0.5, color: PdfColors.grey500),
            pw.SizedBox(height: 8),
            pw.Text(
              'Document généré le ${Fmt.dateTime(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
            PdfThemeService.signatureFooter(),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static Future<void> sharePrint({
    required ReglementFournisseurModel reglement,
    required BoutiqueModel boutique,
    required FournisseurModel fournisseur,
    UserModel? user,
    double? soldeApres,
  }) async {
    final bytes = await build(
      reglement: reglement,
      boutique: boutique,
      fournisseur: fournisseur,
      user: user,
      soldeApres: soldeApres,
    );
    await sharePdfBytes(
      bytes: bytes,
      filename:
          'RecuFournisseur_${boutique.nom}_${fournisseur.nom}_${reglement.id}.pdf',
    );
  }
}

pw.Widget _kv(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    ),
  );
}
