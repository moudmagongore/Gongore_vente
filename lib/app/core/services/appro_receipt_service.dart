import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/approvisionnement_model.dart';
import '../../data/models/boutique_model.dart';
import '../../data/models/fournisseur_model.dart';
import '../../data/models/user_model.dart';
import '../utils/format_helpers.dart';
import 'pdf_theme_service.dart';

/// Génère un bon de réception PDF (format A4 portrait) pour un appro.
class ApproReceiptService {
  static Future<Uint8List> build({
    required ApprovisionnementModel appro,
    required BoutiqueModel boutique,
    required FournisseurModel fournisseur,
    UserModel? user,
  }) async {
    final pdf = pw.Document(theme: await PdfThemeService.theme);
    final devise = boutique.devise;
    final annulee = appro.statut == ApproStatut.annulee;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 24,
          marginBottom: 24,
          marginLeft: 24,
          marginRight: 24,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ====== En-tête boutique + titre ======
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        boutique.nom.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (boutique.adresse?.isNotEmpty ?? false)
                        pw.Text(boutique.adresse!,
                            style: const pw.TextStyle(fontSize: 9)),
                      if (boutique.telephone?.isNotEmpty ?? false)
                        pw.Text('Tél : ${boutique.telephone}',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: annulee ? PdfColors.red50 : PdfColors.blue50,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    annulee ? 'BON ANNULÉ' : 'BON DE RÉCEPTION',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: annulee ? PdfColors.red900 : PdfColors.blue900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Container(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // ====== Méta : N° / date / fournisseur ======
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('N° bon', appro.numeroAffichage, bold: true),
                      _kv('Date', Fmt.dateTime(appro.date)),
                      _kv('Réceptionné par', user?.nom ?? '—'),
                      _kv('Mode paiement', appro.modePaiement.label),
                      if (annulee)
                        _kv('Motif annulation',
                            appro.motifAnnulation ?? '—'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FOURNISSEUR',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          fournisseur.nom,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (fournisseur.telephone?.isNotEmpty ?? false)
                          pw.Text('Tél : ${fournisseur.telephone}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (fournisseur.adresse?.isNotEmpty ?? false)
                          pw.Text(fournisseur.adresse!,
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ====== Tableau articles ======
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(5),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('Article'),
                    _th('Qté', alignRight: true),
                    _th('PA unitaire', alignRight: true),
                    _th('Total', alignRight: true),
                  ],
                ),
                ...appro.articles.map(
                  (a) => pw.TableRow(
                    children: [
                      _td(a.nomComplet),
                      _td('${a.quantite}', alignRight: true),
                      _td(Fmt.money(a.prixAchatUnitaire, currency: devise),
                          alignRight: true),
                      _td(Fmt.money(a.sousTotal, currency: devise),
                          alignRight: true, bold: true),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ====== Totaux ======
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                child: pw.Column(
                  children: [
                    _kv('Sous-total',
                        Fmt.money(appro.sousTotal, currency: devise)),
                    if (appro.remise > 0)
                      _kv(
                        'Remise',
                        '-${Fmt.money(appro.remise, currency: devise)}',
                      ),
                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                      height: 1,
                      color: PdfColors.grey400,
                    ),
                    _kv('TOTAL',
                        Fmt.money(appro.total, currency: devise),
                        bold: true, fontSize: 13),
                    pw.SizedBox(height: 6),
                    _kv('Payé (cash)',
                        Fmt.money(appro.montantPaye, currency: devise)),
                    if (appro.avanceUtilisee > 0)
                      _kv('Avance utilisée',
                          Fmt.money(appro.avanceUtilisee, currency: devise)),
                    if (appro.resteAPayer > 0)
                      _kv(
                        'Reste à payer',
                        Fmt.money(appro.resteAPayer, currency: devise),
                        bold: true,
                      )
                    else if (appro.resteAPayer < 0)
                      _kv(
                        'Trop-versé',
                        Fmt.money(appro.resteAPayer.abs(), currency: devise),
                      ),
                  ],
                ),
              ),
            ),

            if (appro.note?.isNotEmpty ?? false) ...[
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'Note : ${appro.note}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            ],

            pw.Spacer(),

            // ====== Pied : signatures ======
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signature fournisseur',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          )),
                      pw.SizedBox(height: 30),
                      pw.Container(
                          width: 160, height: 0.5, color: PdfColors.grey400),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signature réceptionnaire',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          )),
                      pw.SizedBox(height: 30),
                      pw.Container(
                          width: 160, height: 0.5, color: PdfColors.grey400),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Document généré le ${Fmt.dateTime(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
            ),
            PdfThemeService.signatureFooter(fontSize: 8),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static Future<void> sharePrint({
    required ApprovisionnementModel appro,
    required BoutiqueModel boutique,
    required FournisseurModel fournisseur,
    UserModel? user,
  }) async {
    final bytes = await build(
      appro: appro,
      boutique: boutique,
      fournisseur: fournisseur,
      user: user,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'BonReception_${boutique.nom}_${appro.numeroAffichage}.pdf',
    );
  }
}

pw.Widget _th(String label, {bool alignRight = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );

pw.Widget _td(
  String value, {
  bool alignRight = false,
  bool bold = false,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );

pw.Widget _kv(
  String label,
  String value, {
  bool bold = false,
  double? fontSize,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize ?? 9,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize ?? 9,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
