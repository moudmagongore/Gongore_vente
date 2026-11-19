import 'dart:async';

import 'package:get/get.dart';

/// Remplace `rx.bindStream(stream)` dans les contrôleurs qui rebranchent
/// leurs données (changement de période, de filtre, de boutique).
///
/// `bindStream` de GetX **n'annule jamais** l'abonnement précédent : à
/// chaque rebranchement, l'ancienne requête Firestore reste à l'écoute
/// jusqu'à la fermeture du contrôleur. Les écouteurs s'empilent, chacun
/// facturé en lectures, et un ancien flux peut même réécrire des données
/// périmées dans la variable.
///
/// [bindLive] garde un seul abonnement par variable : brancher un nouveau
/// flux ferme le précédent. Tout est fermé dans `onClose`.
mixin LiveBindings on GetxController {
  final Map<Object, StreamSubscription<dynamic>> _liveSubs = {};

  void bindLive<T>(RxObjectMixin<T> rx, Stream<T> stream) {
    _liveSubs.remove(rx)?.cancel();
    _liveSubs[rx] = stream.listen((v) => rx.value = v);
  }

  @override
  void onClose() {
    for (final s in _liveSubs.values) {
      s.cancel();
    }
    _liveSubs.clear();
    super.onClose();
  }
}
