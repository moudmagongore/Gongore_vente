import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../theme/app_colors.dart';

/// Écran d'aperçu d'un PDF, avec un unique bouton **Partager** centré
/// (l'impression reste accessible depuis le share sheet du système).
///
/// Le bouton "Partager" est placé dans `Scaffold.bottomNavigationBar`
/// plutôt que dans la barre d'actions interne de `PdfPreview` — ça
/// évite l'ombre / l'élévation Material que le package applique
/// automatiquement à sa barre d'actions.
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String filename;
  final String title;
  /// Résolution de rasterisation des pages pour l'aperçu. 400 (défaut)
  /// donne un rendu très net pour les reçus 80mm (1-2 pages). Pour les
  /// documents longs (manuel multi-pages, rapport), baisser à ~150 pour
  /// éviter les OOM Android (chaque page rasterisée occupe DPI² × pages
  /// octets en RAM avant affichage).
  final double dpi;

  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.filename,
    this.title = 'Aperçu',
    this.dpi = 400,
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
        // DPI configurable selon le contexte (par défaut 400 — net pour
        // les reçus 80mm). Pour un doc multi-pages (manuel, rapport),
        // baisser via le paramètre `dpi` du widget pour éviter les OOM.
        dpi: dpi,
        // Désactive complètement la barre d'actions interne du package
        // (sa Material élévée projetait une ombre sous le bouton). Le
        // bouton partage est géré par `Scaffold.bottomNavigationBar`.
        allowPrinting: false,
        allowSharing: false,
        useActions: false,
        // Force le fond de la zone qui entoure le reçu en blanc — sinon
        // PdfPreview utilise une couleur grise par défaut qui empêchait
        // [Scaffold.backgroundColor: Colors.white] de prendre effet.
        scrollViewDecoration: const BoxDecoration(color: Colors.white),
        // Espace autour du reçu : un peu d'air sous l'AppBar et de chaque
        // côté, pour ne pas que le reçu colle au header.
        previewPageMargin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        // Décoration de page : fond blanc + ombre douce centrée pour que
        // le reçu se détache du fond sans déborder.
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 1),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
      // Barre du bouton "Partager" en bas, contrôlée par nous —
      // pas d'élévation, pas d'ombre parasite. La SafeArea pousse le
      // bouton au-dessus du système de navigation (Android / iOS).
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Center(
              child: IconButton(
                tooltip: 'Partager',
                icon: const Icon(Icons.share, color: navy, size: 28),
                onPressed: () =>
                    Printing.sharePdf(bytes: bytes, filename: filename),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
