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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        
        build: (_) async => bytes,
        pdfFileName: filename,
        // Le format est figé côté générateur (roll80 / A4) — on ne laisse
        // pas l'utilisateur le changer ici.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        // L'impression est déjà disponible dans le share sheet → on cache
        // le bouton dédié pour ne garder qu'un seul bouton « Partager »
        // centré dans la barre d'actions.
        allowPrinting: false,
        allowSharing: false,
        // Action « Partager » custom : on contrôle explicitement la couleur
        // de l'icône (le package 5.13.4 n'applique pas toujours
        // [actionBarTheme.iconColor] à ses actions natives, d'où l'icône
        // qui restait noire).
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: (ctx, build, format) async {
              final pdf = await build(format);
              await Printing.sharePdf(bytes: pdf, filename: filename);
            },
          ),
        ],
        actionBarTheme: PdfActionBarTheme(
          alignment: WrapAlignment.center,
          backgroundColor: AppColors.primary(context),
          iconColor: Colors.white,
          textStyle: const TextStyle(color: Colors.white),
        ),
        // Décoration de page minimaliste : fond blanc + bordure légère,
        // ombre quasi nulle (le défaut du package est très marquée).
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
