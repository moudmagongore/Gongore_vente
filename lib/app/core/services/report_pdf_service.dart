import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/format_helpers.dart';
import '../../data/models/vente_model.dart';
import '../constants/app_constants.dart';
import '../utils/pdf_share_helper.dart';
import 'pdf_theme_service.dart';

class ReportData {
  final DateTime debut;
  final DateTime fin;
  final String? boutiqueNom;
  final String? vendeurNom;
  final int nbVentes;
  final int nbAnnulees;
  final double caTotal;
  final double benefice;
  final int nbArticles;
  final Map<ModePaiement, double> caParPaiement;
  final List<({String nom, int qte, double ca})> topProduits;

  // ====== Achats ======
  final int nbAppros;
  final double totalAchats;
  final double margePeriode;
  final double detteFournisseurPeriode;
  final double detteFournisseurGlobale;
  final List<({String nom, int nbAppros, double total})> topFournisseurs;

  final String devise;

  ReportData({
    required this.debut,
    required this.fin,
    this.boutiqueNom,
    this.vendeurNom,
    required this.nbVentes,
    required this.nbAnnulees,
    required this.caTotal,
    required this.benefice,
    required this.nbArticles,
    required this.caParPaiement,
    required this.topProduits,
    this.nbAppros = 0,
    this.totalAchats = 0,
    this.margePeriode = 0,
    this.detteFournisseurPeriode = 0,
    this.detteFournisseurGlobale = 0,
    this.topFournisseurs = const [],
    this.devise = 'GNF',
  });
}

class ReportPdfService {
  static Future<Uint8List> build(ReportData data) async {
    final pdf = pw.Document(theme: await PdfThemeService.theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        // Pied de page sur chaque page : signature « © <année> Gongore »
        // + numéro de page courant.
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(
            children: [
              PdfThemeService.signatureFooter(fontSize: 8),
              pw.SizedBox(height: 2),
              pw.Text(
                'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // ====== En-tête ======
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Rapport de ventes',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Période : du ${Fmt.dateShort(data.debut)} au ${Fmt.dateShort(data.fin)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                if (data.boutiqueNom != null)
                  pw.Text(
                    'Boutique : ${data.boutiqueNom}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                if (data.vendeurNom != null)
                  pw.Text(
                    'Gestionnaire : ${data.vendeurNom}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                pw.Text(
                  'Édité le ${Fmt.dateTime(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ====== KPIs ======
          pw.Text(
            'Indicateurs',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiBox(
                'Chiffre d\'affaires',
                Fmt.money(data.caTotal, currency: data.devise),
                PdfColors.blue700,
              ),
              _kpiBox(
                'Bénéfice estimé',
                Fmt.money(data.benefice, currency: data.devise),
                PdfColors.green700,
              ),
              _kpiBox('Ventes validées', '${data.nbVentes}', PdfColors.indigo),
              _kpiBox(
                'Articles vendus',
                '${data.nbArticles}',
                PdfColors.purple,
              ),
              _kpiBox(
                'Annulations',
                '${data.nbAnnulees}',
                PdfColors.red700,
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // ====== Modes de paiement ======
          pw.Text(
            'Répartition par mode de paiement',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (data.caParPaiement.isEmpty)
            pw.Text(
              'Aucune donnée',
              style: pw.TextStyle(color: PdfColors.grey),
            )
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              data: [
                ['Mode', 'Montant', '% du chiffre d\'affaires'],
                ...data.caParPaiement.entries.map((e) {
                  final pct = data.caTotal == 0
                      ? 0
                      : (e.value / data.caTotal) * 100;
                  return [
                    e.key.label,
                    Fmt.money(e.value, currency: data.devise),
                    '${pct.toStringAsFixed(1)} %',
                  ];
                }),
              ],
            ),
          pw.SizedBox(height: 24),

          // ====== Top produits ======
          pw.Text(
            'Top produits vendus',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (data.topProduits.isEmpty)
            pw.Text('Aucune donnée',
                style: pw.TextStyle(color: PdfColors.grey))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              data: [
                ['#', 'Produit', 'Quantité', 'Chiffre d\'affaires'],
                ...data.topProduits.take(20).toList().asMap().entries.map(
                      (e) => [
                        '${e.key + 1}',
                        e.value.nom,
                        '${e.value.qte}',
                        Fmt.money(e.value.ca, currency: data.devise),
                      ],
                    ),
              ],
            ),
          pw.SizedBox(height: 24),

          // ====== Achats ======
          pw.Text(
            'Achats & fournisseurs',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiBox(
                'Total achats',
                Fmt.money(data.totalAchats, currency: data.devise),
                PdfColors.deepPurple,
              ),
              _kpiBox(
                'Approvisionnements',
                '${data.nbAppros}',
                PdfColors.indigo,
              ),
              _kpiBox(
                'Marge brute (CA - achats)',
                Fmt.money(data.margePeriode, currency: data.devise),
                data.margePeriode >= 0
                    ? PdfColors.green700
                    : PdfColors.red700,
              ),
              _kpiBox(
                'Dette appros période',
                Fmt.money(data.detteFournisseurPeriode,
                    currency: data.devise),
                PdfColors.orange700,
              ),
              _kpiBox(
                'Dette fournisseur totale',
                Fmt.money(data.detteFournisseurGlobale,
                    currency: data.devise),
                PdfColors.red700,
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // ====== Top fournisseurs ======
          pw.Text(
            'Top fournisseurs',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (data.topFournisseurs.isEmpty)
            pw.Text('Aucun appro sur cette période',
                style: pw.TextStyle(color: PdfColors.grey))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              data: [
                ['#', 'Fournisseur', 'Appros', 'Total acheté'],
                ...data.topFournisseurs
                    .take(20)
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (e) => [
                        '${e.key + 1}',
                        e.value.nom,
                        '${e.value.nbAppros}',
                        Fmt.money(e.value.total, currency: data.devise),
                      ],
                    ),
              ],
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _kpiBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: color.shade(0.92),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color.shade(0.7), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> sharePrint(ReportData data) async {
    final bytes = await build(data);
    await sharePdfBytes(
      bytes: bytes,
      filename:
          'Rapport_${Fmt.dateShort(data.debut)}_${Fmt.dateShort(data.fin)}.pdf'
              .replaceAll('/', '-'),
      previewTitle: 'Rapport',
    );
  }
}
