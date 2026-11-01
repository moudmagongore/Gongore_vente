import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/mouvement_caisse_model.dart';
import '../../data/repositories/boutique_repository.dart';
import '../../modules/admin/caisses/controllers/releve_caisse_controller.dart';
import '../utils/format_helpers.dart';
import '../utils/pdf_share_helper.dart';
import 'pdf_theme_service.dart';

/// Export PDF du relevé de caisse (RG-29).
///
/// Format A4 et non 80 mm : un relevé est un document de contrôle qu'on
/// lit à plat ou qu'on envoie, pas un ticket qu'on remet au client.
class ReleveCaissePdfService {
  /// Construit et ouvre l'aperçu. Les données viennent du controller déjà
  /// à l'écran : ce que l'utilisateur voit est ce qu'il exporte, filtre de
  /// type compris.
  static Future<void> exporter(ReleveCaisseController c) async {
    final caisse = c.caisse.value;
    if (caisse == null) return;

    final boutique = await BoutiqueRepository().getById(caisse.boutiqueId);
    final bytes = await _build(
      c: c,
      nomBoutique: boutique?.nom ?? '',
      devise: boutique?.devise ?? 'GNF',
    );

    final nomFichier =
        'releve-${caisse.nom.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')}'
        '-${Fmt.dateShort(DateTime.now()).replaceAll('/', '-')}.pdf';
    await sharePdfBytes(
      bytes: bytes,
      filename: nomFichier,
      previewTitle: 'Relevé — ${caisse.nom}',
    );
  }

  static Future<Uint8List> _build({
    required ReleveCaisseController c,
    required String nomBoutique,
    required String devise,
  }) async {
    final pdf = pw.Document(theme: await PdfThemeService.theme);
    final caisse = c.caisse.value!;
    final mouvements = c.filtered;
    String money(double v) => Fmt.money(v, currency: devise);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  'Relevé — ${caisse.nom} (suite)',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600),
                ),
              ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            nomBoutique.isEmpty ? 'Relevé de caisse' : nomBoutique,
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Relevé de caisse — ${caisse.nom}',
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${c.libellePeriode} · édité le ${Fmt.dateTime(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          if (c.estFiltre)
            pw.Text(
              'Filtré sur : ${c.filterType.value!.label}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 14),

          // ====== Synthèse ======
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                _ligne('Solde au début', money(c.soldeDebut.value)),
                _ligne('Total des entrées', '+ ${money(c.totalEntrees)}'),
                _ligne('Total des sorties', '- ${money(c.totalSorties)}'),
                pw.Divider(height: 8),
                _ligne('Solde à la fin', money(c.soldeFin), gras: true),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ====== Mouvements ======
          if (mouvements.isEmpty)
            pw.Text(
              'Aucun mouvement sur la période.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            )
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(2.4),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.8),
                5: const pw.FlexColumnWidth(1.8),
              },
              cellAlignments: {
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              data: [
                ['Date', 'Type', 'Entrée', 'Sortie', 'Solde', 'Auteur'],
                // Le relevé se lit du plus ancien au plus récent : la
                // colonne « Solde » doit s'enchaîner de haut en bas.
                ...mouvements.reversed.map((m) {
                  final entree = m.sens == SensMouvement.entree;
                  return [
                    Fmt.dateTime(m.date),
                    _libelle(m),
                    entree ? money(m.montant) : '',
                    entree ? '' : money(m.montant),
                    money(m.soldeApres),
                    m.userNom,
                  ];
                }),
              ],
            ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Type, numéro d'opération et motif réunis en une cellule : le tableau
  /// resterait illisible avec une colonne par information.
  static String _libelle(MouvementCaisseModel m) {
    final parts = <String>[m.type.label];
    if (m.numero?.isNotEmpty ?? false) parts.add(m.numero!);
    if (m.motif?.isNotEmpty ?? false) parts.add(m.motif!);
    return parts.join(' · ');
  }

  static pw.Widget _ligne(String label, String valeur, {bool gras = false}) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(valeur, style: style),
        ],
      ),
    );
  }
}
