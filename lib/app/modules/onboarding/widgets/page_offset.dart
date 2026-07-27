import 'package:flutter/widgets.dart';

/// Position courante du PageView en valeur continue (`2.4` = entre la 3e et
/// la 4e page). C'est elle qui pilote le parallaxe et l'interpolation du
/// dégradé pendant que le doigt fait glisser la page.
///
/// Tant que le PageView n'a pas été layouté, on retombe sur `initialPage` et
/// non sur `0` : lire `PageController.page` avant ce moment déclenche une
/// assertion, et le PageController ne notifie ses listeners qu'au scroll. Un
/// slide construit hors du tout premier rendu resterait donc figé sur un
/// offset faux — donc invisible, puisque l'opacité en dépend.
double pageOffsetOf(PageController controller) {
  final fallback = controller.initialPage.toDouble();
  if (!controller.hasClients) return fallback;
  final position = controller.position;
  if (!position.hasPixels || !position.hasContentDimensions) return fallback;
  return controller.page ?? fallback;
}
