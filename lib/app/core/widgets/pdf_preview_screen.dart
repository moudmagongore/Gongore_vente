import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../theme/app_colors.dart';

/// Écran d'aperçu d'un PDF, avec un unique bouton **Partager** centré
/// (l'impression reste accessible depuis le share sheet du système).
///
/// Utilisé sur iOS où l'aperçu d'impression natif (UIPrintInteractionController)
/// affiche les reçus 80mm à leur taille réelle (illisible sans zoom). Le
/// widget `PdfPreview` du package `printing` rend la page en fit-to-screen
/// avec pinch-zoom.
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String filename;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.filename,
    this.title = 'Aperçu',
  });

  @override
  Widget build(BuildContext context) {
    // Couleur navy fixe utilisée pour le titre / les icônes / le bouton
    // partage. Hardcodée à `Color(0xFF194565)` (= AppColors.primaryFixed)
    // pour rester identique en mode clair comme en mode sombre.
    const navy = AppColors.primaryFixed;
    return Scaffold(
      // Fond blanc autour du reçu, indépendant du thème (clair OU sombre).
      backgroundColor: Colors.white,
      appBar: AppBar(
        // En-tête forcée en blanc + titre/icônes en navy, même en dark mode.
        backgroundColor: Colors.white,
        foregroundColor: navy,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: navy),
        title: Text(
          title,
          style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
        ),
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: filename,
        // Le format est figé côté générateur (roll80 / A4) — on ne laisse
        // pas l'utilisateur le changer ici.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        // DPI très élevé pour un rendu vraiment net du texte, même sur les
        // petites polices 8-9pt des reçus thermiques 80mm. 300 est la
        // résolution d'impression standard ; on monte un peu au-dessus
        // pour couvrir les écrans Retina / haute densité.
        dpi: 400,
        // L'impression est déjà disponible dans le share sheet → on cache
        // le bouton dédié pour ne garder qu'un seul bouton « Partager »
        // centré dans la barre d'actions.
        allowPrinting: false,
        allowSharing: false,
        // Action « Partager » custom : icône navy `0xFF194565`, plus grande
        // que le défaut (28 vs 24) pour un bouton plus visible.
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share, color: navy, size: 28),
            onPressed: (ctx, build, format) async {
              final pdf = await build(format);
              await Printing.sharePdf(bytes: pdf, filename: filename);
            },
          ),
        ],
        actionBarTheme: const PdfActionBarTheme(
          alignment: WrapAlignment.center,
          // Fond du bouton partage en blanc, comme l'AppBar et le scroll
          // view : tout l'écran reste blanc, même en mode sombre.
          backgroundColor: Colors.white,
          iconColor: navy,
          textStyle: TextStyle(color: navy),
          // Barre plus haute pour agrandir la zone tactile du bouton.
          height: 64,
        ),
        // Force le fond de la zone qui entoure le reçu en blanc — sinon
        // PdfPreview utilise une couleur grise par défaut qui empêchait
        // [Scaffold.backgroundColor: Colors.white] de prendre effet.
        scrollViewDecoration: const BoxDecoration(color: Colors.white),
        // Espace autour du reçu : un peu d'air sous l'AppBar et de chaque
        // côté, pour ne pas que le reçu colle au header.
        previewPageMargin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        // Décoration de page : fond blanc + ombre prononcée (deux couches)
        // pour que le reçu se détache nettement du fond blanc du Scaffold.
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            // Halo doux autour de la page
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              offset: const Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
            // Ombre principale en bas, marquée
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              offset: const Offset(0, 8),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
