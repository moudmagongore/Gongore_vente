import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/boutique_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/vente_model.dart';
import '../utils/format_helpers.dart';

/// Génère un reçu PDF (format 80mm classique pour imprimante thermique).
class ReceiptService {
  static Future<Uint8List> build({
    required VenteModel vente,
    required BoutiqueModel boutique,
    UserModel? vendeur,
    String? clientLabel,
  }) async {
    final pdf = pw.Document();
    final devise = boutique.devise;

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
            // ====== En-tête ======
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
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            // ====== Méta ======
            _kvRow('Date', Fmt.dateTime(vente.date)),
            _kvRow('Client', clientLabel ?? vente.clientLabelOuLibre),
            _kvRow('Gestionnaire', vendeur?.nom ?? '—'),
            _kvRow('N° vente', vente.numeroAffichage),
            _kvRow('Paiement', vente.modePaiement.label),
            if (vente.statut == VenteStatut.annulee)
              _kvRow('Statut', 'ANNULÉE',
                  bold: true),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            // ====== Articles ======
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    'Article',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Qté',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Total',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            ...vente.articles.map(
              (a) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            a.nom,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '${a.quantite}',
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            Fmt.money(a.sousTotal, currency: devise),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 4),
                      child: pw.Text(
                        '@ ${Fmt.money(a.prixUnitaire, currency: devise)}'
                        '${a.remise > 0 ? ' (remise ${Fmt.money(a.remise, currency: devise)})' : ''}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            // ====== Totaux ======
            _kvRow('Sous-total', Fmt.money(vente.sousTotal, currency: devise)),
            if (vente.remise > 0)
              _kvRow('Remise',
                  '-${Fmt.money(vente.remise, currency: devise)}'),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  Fmt.money(vente.total, currency: devise),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            _kvRow('Montant payé (cash)',
                Fmt.money(vente.montantPaye, currency: devise)),
            if (vente.avanceUtilisee > 0)
              _kvRow('Avance utilisée',
                  Fmt.money(vente.avanceUtilisee, currency: devise)),
            if (vente.resteAPayer > 0)
              _kvRow(
                'Reste à payer (crédit)',
                Fmt.money(vente.resteAPayer, currency: devise),
                bold: true,
              )
            else if (vente.resteAPayer < 0)
              _kvRow(
                'Trop-perçu',
                Fmt.money(vente.resteAPayer.abs(), currency: devise),
              ),
            if (vente.note?.isNotEmpty ?? false) ...[
              pw.SizedBox(height: 6),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Note : ${vente.note}',
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

            // ====== Pied ======
            pw.Text(
              'Merci de votre visite !',
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

  /// Lance le partage / impression natif.
  static Future<void> sharePrint({
    required VenteModel vente,
    required BoutiqueModel boutique,
    UserModel? vendeur,
    String? clientLabel,
  }) async {
    final bytes = await build(
      vente: vente,
      boutique: boutique,
      vendeur: vendeur,
      clientLabel: clientLabel,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name:
          'Recu_${boutique.nom}_${vente.numeroAffichage}.pdf',
    );
  }
}

/// Helper d'une ligne label/value en PDF.
// ignore: non_constant_identifier_names
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
