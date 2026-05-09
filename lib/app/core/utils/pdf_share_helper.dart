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
Future<void> sharePdfBytes({
  required Uint8List bytes,
  required String filename,
  String previewTitle = 'Aperçu',
}) async {
  await Get.to<void>(
    () => PdfPreviewScreen(
      bytes: bytes,
      filename: filename,
      title: previewTitle,
    ),
  );
}
