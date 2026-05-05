import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Hauteur max d'un bottom sheet, en fraction de l'écran. On laisse
/// volontairement assez de marge en haut pour que l'AppBar reste visible
/// quand le clavier s'ouvre ou pendant le scroll.
const double kBottomSheetMaxHeightRatio = 0.85;

/// Wrappe le contenu d'un bottom sheet avec :
///
/// - une hauteur max = [kBottomSheetMaxHeightRatio] de l'écran (l'AppBar
///   reste visible quand le clavier s'ouvre, pas de débordement vers le
///   haut, le sheet ne prend jamais toute la hauteur)
/// - une `SafeArea(top: false)` UNIQUEMENT sur Android (la barre de gestes
///   y est plus basse et masque le contenu sans padding). Sur iOS, le
///   moteur natif gère déjà le home-indicator côté bottom sheet, donc on
///   évite la double-marge en sautant le SafeArea.
///
/// À utiliser comme wrapper du widget passé à `Get.bottomSheet(...)` ou
/// de l'enfant d'un `DraggableScrollableSheet`.
Widget wrapBottomSheet(BuildContext context, Widget child) {
  final maxH =
      MediaQuery.of(context).size.height * kBottomSheetMaxHeightRatio;
  Widget content = ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxH),
    child: child,
  );
  if (Platform.isAndroid) {
    content = SafeArea(top: false, child: content);
  }
  return content;
}

/// SafeArea(top: false) appliqué UNIQUEMENT sur Android.
/// iOS gère déjà le home-indicator côté moteur de bottom sheet, donc on
/// l'évite pour ne pas avoir de double-marge en bas.
Widget androidOnlySafeArea(Widget child) {
  if (Platform.isAndroid) {
    return SafeArea(top: false, child: child);
  }
  return child;
}
