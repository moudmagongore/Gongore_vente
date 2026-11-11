import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/categorie_model.dart';
import '../../data/models/produit_model.dart';
import '../../data/repositories/categorie_repository.dart';
import '../../data/repositories/produit_repository.dart';

/// Cache partagé du catalogue : produits et catégories, par boutique.
///
/// **Pourquoi ce service existe.** Neuf contrôleurs avaient besoin du
/// catalogue produits et sept des catégories. Chacun ouvrait son propre
/// `snapshots()`, et Firestore facture un document lu par document renvoyé
/// **à chaque ouverture d'écouteur** : visiter Ventes, Rapports, Stock puis
/// Catégories relisait quatre fois la totalité du catalogue. Sur une
/// boutique de 800 produits, une navigation ordinaire coûtait des milliers
/// de lectures.
///
/// Ici, un seul écouteur par boutique sert tout le monde, et il reste
/// ouvert pour la session. Un écouteur maintenu ne coûte que les documents
/// qui changent — or un catalogue bouge rarement.
///
/// **Le contrat vu des contrôleurs ne change pas** : ils reçoivent un
/// `Stream` qui émet immédiatement la valeur courante puis les mises à
/// jour, exactement comme `snapshots()`. Leur `bindStream`, leurs `Obx` et
/// leur cycle de vie sont inchangés.
class CatalogueCacheService extends GetxService {
  static CatalogueCacheService get to => Get.find<CatalogueCacheService>();

  final ProduitRepository _produitRepo = ProduitRepository();
  final CategorieRepository _categorieRepo = CategorieRepository();

  final _produits = <String, RxList<ProduitModel>>{};
  final _categories = <String, RxList<CategorieModel>>{};
  final _abonnements = <String, StreamSubscription<dynamic>>{};

  /// Clé de cache. `null` = super-admin, qui voit toutes les boutiques :
  /// c'est un périmètre à part entière, pas une absence de périmètre.
  String _cle(String? boutiqueId) =>
      (boutiqueId == null || boutiqueId.isEmpty) ? '*' : boutiqueId;

  /// Produits d'une boutique — **tous**, actifs ou non.
  ///
  /// Les appelants qui ne veulent que les actifs filtrent côté client : la
  /// donnée est déjà en mémoire, la filtrer ne coûte rien, alors qu'une
  /// requête distincte `active == true` ouvrirait un second écouteur et
  /// doublerait la facture.
  Stream<List<ProduitModel>> watchProduits(String? boutiqueId) {
    final cle = _cle(boutiqueId);
    final liste = _produits.putIfAbsent(cle, () {
      final rx = <ProduitModel>[].obs;
      _abonnements['produits:$cle'] = _produitRepo
          .watchAll(boutiqueId: boutiqueId)
          .listen(rx.assignAll);
      return rx;
    });
    return _flux(liste);
  }

  Stream<List<CategorieModel>> watchCategories(String? boutiqueId) {
    final cle = _cle(boutiqueId);
    final liste = _categories.putIfAbsent(cle, () {
      final rx = <CategorieModel>[].obs;
      _abonnements['categories:$cle'] = _categorieRepo
          .watchAll(boutiqueId: boutiqueId)
          .listen(rx.assignAll);
      return rx;
    });
    return _flux(liste);
  }

  /// Rejoue la valeur courante au nouvel abonné, puis suit les
  /// changements.
  ///
  /// Sans ce rejeu, un écran ouvert après le premier chargement resterait
  /// vide jusqu'à la prochaine modification du catalogue — c'est le défaut
  /// d'un `asBroadcastStream`, qui ne livre que les événements suivants.
  Stream<List<T>> _flux<T>(RxList<T> liste) async* {
    yield liste.toList();
    yield* liste.stream.map((l) => l.toList());
  }

  /// Vide le cache et ferme les écouteurs. À appeler à la déconnexion :
  /// le catalogue de l'utilisateur précédent n'a plus à être ni gardé en
  /// mémoire, ni écouté.
  void vider() {
    for (final sub in _abonnements.values) {
      sub.cancel();
    }
    _abonnements.clear();
    _produits.clear();
    _categories.clear();
  }

  @override
  void onClose() {
    vider();
    super.onClose();
  }
}
