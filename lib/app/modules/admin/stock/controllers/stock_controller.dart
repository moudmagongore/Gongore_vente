import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';
import '../../../../data/repositories/produit_repository.dart';

enum StockFiltreEtat { tous, rupture, bas, normal }

class StockController extends GetxController {
  final ProduitRepository _produitRepo = ProduitRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final CategorieRepository _catRepo = CategorieRepository();

  final RxList<ProduitModel> _all = <ProduitModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<CategorieModel> categories = <CategorieModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;
  final RxnString filterCategorieId = RxnString();
  final Rx<StockFiltreEtat> filterEtat = StockFiltreEtat.tous.obs;
  /// Filtre boutique (super-admin uniquement). null = toutes.
  final RxnString filterBoutiqueId = RxnString();
  /// false = on cache les inactifs, true = on les inclut.
  final RxBool inclureInactifs = false.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    _all.bindStream(_produitRepo.watchAll(boutiqueId: scope));
    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: scope, actives: true),
    );
    categories.bindStream(_catRepo.watchAll(boutiqueId: scope));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  // ===== Helpers =====
  StockFiltreEtat etatProduit(ProduitModel p) {
    if (p.quantiteStock <= 0) return StockFiltreEtat.rupture;
    if (p.quantiteStock <= p.seuilAlerte) return StockFiltreEtat.bas;
    return StockFiltreEtat.normal;
  }

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String? categorieNom(String? id) {
    if (id == null) return null;
    return categories.firstWhereOrNull((c) => c.id == id)?.nom;
  }

  String deviseDe(String boutiqueId) =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId)?.devise ?? 'GNF';

  // ===== Liste filtrée =====
  /// Tri par défaut : ruptures d'abord (qté ascendante), pour attirer
  /// l'attention sur les produits à réapprovisionner.
  List<ProduitModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final boutiqueFilter = filterBoutiqueId.value;
    final list = _all.where((p) {
      if (!inclureInactifs.value && !p.active) return false;
      // Filtre boutique (super-admin)
      if (boutiqueFilter != null && p.boutiqueId != boutiqueFilter) {
        return false;
      }
      if (filterCategorieId.value != null &&
          p.categorieId != filterCategorieId.value) {
        return false;
      }
      if (filterEtat.value != StockFiltreEtat.tous &&
          etatProduit(p) != filterEtat.value) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.nom.toLowerCase().contains(q) ||
          (p.description?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => a.quantiteStock.compareTo(b.quantiteStock));
    return list;
  }

  // ===== Stats scopées au filtre boutique (super-admin) =====
  /// Produits actifs respectant le filtre boutique courant. Utilisé pour
  /// calculer les statistiques (nb produits, ruptures, valeurs) afin que
  /// les chiffres reflètent la boutique sélectionnée.
  List<ProduitModel> get _actifsScopes {
    final boutiqueFilter = filterBoutiqueId.value;
    return _all.where((p) {
      if (!p.active) return false;
      if (boutiqueFilter != null && p.boutiqueId != boutiqueFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  // ===== Stats =====
  // Les stats utilisent `_actifsScopes` (défini plus haut) qui respecte
  // le filtre boutique — pour le super-admin avec un filtre actif, les
  // chiffres reflètent la boutique sélectionnée.
  int get nbProduits => _actifsScopes.length;
  int get nbRuptures =>
      _actifsScopes.where((p) => p.quantiteStock <= 0).length;
  int get nbStockBas => _actifsScopes
      .where((p) =>
          p.quantiteStock > 0 && p.quantiteStock <= p.seuilAlerte)
      .length;

  /// Valeur totale du stock au PA (CMUP).
  double get valeurStock =>
      _actifsScopes.fold(0.0, (acc, p) => acc + p.valeurStock);

  /// Valeur potentielle au prix de vente (CA potentiel).
  double get valeurStockVente => _actifsScopes.fold(
      0.0, (acc, p) => acc + p.quantiteStock * p.prixVente);

  /// Marge potentielle = valeur vente - valeur achat.
  double get margePotentielle => valeurStockVente - valeurStock;

  Color etatColor(StockFiltreEtat etat) {
    switch (etat) {
      case StockFiltreEtat.rupture:
        return Colors.red;
      case StockFiltreEtat.bas:
        return Colors.orange;
      case StockFiltreEtat.normal:
        return Colors.green;
      case StockFiltreEtat.tous:
        return Colors.grey;
    }
  }

  String etatLabel(StockFiltreEtat etat) {
    switch (etat) {
      case StockFiltreEtat.rupture:
        return 'Rupture';
      case StockFiltreEtat.bas:
        return 'Stock bas';
      case StockFiltreEtat.normal:
        return 'OK';
      case StockFiltreEtat.tous:
        return 'Tous';
    }
  }
}
