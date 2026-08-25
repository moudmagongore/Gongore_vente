import 'dart:async';

import 'package:flutter/widgets.dart';

/// Neutralise les taps sur le contenu du drawer pendant son animation
/// d'ouverture (246 ms côté framework).
///
/// Pourquoi : pendant le slide-in, `DrawerController` place le drawer dans un
/// `Align(widthFactor: animation.value)` aligné sur son bord droit. Seule la
/// bande déjà visible est hit-testable, mais elle l'est *complètement*, et
/// elle affiche la partie droite du drawer collée au bord gauche de l'écran.
/// Un tap qui arrive à cet instant au coin haut-gauche — exactement là où se
/// trouve le bouton hamburger qui vient d'ouvrir le drawer — atterrit donc sur
/// le contenu du drawer et peut activer un item que l'utilisateur n'a jamais
/// visé (« Mon compte », un item de la liste…).
///
/// Le symptôme est surtout visible sur tablette (écran plus grand, animation
/// perçue plus lente, tap répété sur le hamburger fréquent) alors qu'il est
/// quasi inatteignable sur téléphone.
///
/// Le sous-arbre du drawer est reconstruit à chaque ouverture (il est retiré
/// dès que l'animation est retombée à 0), donc `initState` — et le timer —
/// repartent bien à chaque fois.
class DrawerOpenGuard extends StatefulWidget {
  final Widget child;

  const DrawerOpenGuard({super.key, required this.child});

  @override
  State<DrawerOpenGuard> createState() => _DrawerOpenGuardState();
}

class _DrawerOpenGuardState extends State<DrawerOpenGuard> {
  /// Marge au-dessus des 246 ms de l'animation d'ouverture du drawer.
  static const _guardDuration = Duration(milliseconds: 320);

  bool _ignoring = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_guardDuration, () {
      if (mounted) setState(() => _ignoring = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AbsorbPointer plutôt qu'IgnorePointer : le tap parasite doit être
    // consommé, sinon il traverse jusqu'au scrim qui referme le drawer.
    return AbsorbPointer(absorbing: _ignoring, child: widget.child);
  }
}
