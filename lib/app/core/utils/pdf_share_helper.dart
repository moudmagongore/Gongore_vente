import 'dart:typed_data';

import 'package:get/get.dart';

import '../widgets/pdf_preview_screen.dart';

/// Affichage / partage d'un PDF via un écran in-app unifié (iOS + Android).
///
/// On ouvre `PdfPreviewScreen` (basé sur le widget `PdfPreview` du package
/// `printing`) qui rend le PDF en fit-to-screen avec pinch-zoom et expose
/// un bouton « Partager » centré. Depuis le share sheet, l'utilisateur
/// peut imprimer, enregistrer dans Files / Mes fichiers, ou partager via
/// WhatsApp / mail / etc.
///
/// Une seule méthode pour les deux plateformes : comportement identique,
/// pas de divergence iOS vs Android à maintenir.
/// [dpi] : résolution de rasterisation de l'**aperçu** seulement — le
/// fichier partagé ou imprimé garde sa qualité d'origine.
///
/// Le défaut de 150 est volontairement prudent. Une page A4 rasterisée à
/// 400 dpi fait 3308 × 4676 pixels, soit environ 62 Mo en mémoire ; deux
/// pages suffisent à dépasser le tas Android et à tuer l'application
/// (`OutOfMemoryError` dans `PrintingJob.rasterPdf`). C'est arrivé sur le
/// rapport de ventes dès qu'il a atteint deux pages.
///
/// Les tickets 80 mm, eux, sont assez petits pour supporter 400 dpi : ils
/// le demandent explicitement. Mieux vaut qu'un format inhabituel hérite
/// d'une valeur sûre plutôt que de compter sur la mémoire de l'appelant.
Future<void> sharePdfBytes({
  required Uint8List bytes,
  required String filename,
  String previewTitle = 'Aperçu',
  double dpi = 150,
}) async {
  await Get.to<void>(
    () => PdfPreviewScreen(
      bytes: bytes,
      filename: filename,
      title: previewTitle,
      dpi: dpi,
    ),
    routeName: '/pdf-preview',
  );
}
