import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/boutique_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/reglement_model.dart';
import '../../data/models/user_model.dart';
import '../utils/format_helpers.dart';

/// Génère un reçu PDF pour un règlement (encaissement). Format 80mm
/// pour imprimante thermique.
class ReglementReceiptService {
  static Future<Uint8List> build({
    required ReglementModel reglement,
    required BoutiqueModel boutique,
    required ClientModel client,
    UserModel? vendeur,
    double? soldeApres,
  }) async {
    final pdf = pw.Document();
    final devise = boutique.devise;
    final numero = reglement.id.isEmpty
        ? '—'
        : 'R-${reglement.id.substring(0, reglement.id.length < 6 ? reglement.id.length : 6).toUpperCase()}';

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
              'REÇU DE RÈGLEMENT',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            _kvRow('N°', numero),
            _kvRow('Date', Fmt.dateTime(reglement.date)),
            _kvRow('Client', client.nom),
            if (client.telephone?.isNotEmpty ?? false)
              _kvRow('Téléphone', client.telephone!),
            _kvRow('Gestionnaire', vendeur?.nom ?? '—'),
            _kvRow('Mode', reglement.modePaiement.label),

            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MONTANT REÇU',
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
                  'Imputations sur ventes',
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
                            (i.venteId.isNotEmpty
                                ? i.venteId.substring(
                                    0,
                                    i.venteId.length < 8
                                        ? i.venteId.length
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
              _kvRow(
                'Avance déposée',
                Fmt.money(reglement.surplus, currency: devise),
                bold: true,
              ),
            ],

            if (soldeApres != null) ...[
              pw.SizedBox(height: 4),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              _kvRow(
                soldeApres > 0
                    ? 'Reste dû'
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
              'Merci pour votre règlement !',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Reçu généré le ${Fmt.dateTime(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static Future<void> sharePrint({
    required ReglementModel reglement,
    required BoutiqueModel boutique,
    required ClientModel client,
    UserModel? vendeur,
    double? soldeApres,
  }) async {
    final bytes = await build(
      reglement: reglement,
      boutique: boutique,
      client: client,
      vendeur: vendeur,
      soldeApres: soldeApres,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Recu_${boutique.nom}_${client.nom}_${reglement.id}.pdf',
    );
  }
}

pw.Widget _kvRow(String label, String value, {bool bold = false}) {
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
