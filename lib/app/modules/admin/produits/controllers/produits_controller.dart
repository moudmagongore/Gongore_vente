import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/stock_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/stock_repository.dart';

class ProduitsController extends GetxController {
  final ProduitRepository _repo = ProduitRepository();
  final CategorieRepository _catRepo = CategorieRepository();
  final BoutiqueRepository _boutRepo = BoutiqueRepository();
  final StockRepository _stockRepo = StockRepository();

  final RxList<ProduitModel> _all = <ProduitModel>[].obs;
  final RxList<CategorieModel> categories = <CategorieModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<StockModel> _stocks = <StockModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterCategorieId = RxnString();
  final RxBool onlyActive = false.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    _all.bindStream(_repo.watchAll(boutiqueId: scope));
    categories.bindStream(_catRepo.watchAll(boutiqueId: scope));
    boutiques.bindStream(
      _boutRepo.watchScoped(scope: scope, actives: true),
    );
    _stocks.bindStream(_stockRepo.watchScoped(scope));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  /// Quantité en stock pour un produit donné dans sa boutique.
  int stockOf(ProduitModel p) {
    return _stocks
            .firstWhereOrNull(
                (s) => s.produitId == p.id && s.boutiqueId == p.boutiqueId)
            ?.quantite ??
        0;
  }

  List<ProduitModel> get filtered {
    final q = search.value.trim().toLowerCase();
    return _all.where((p) {
      if (filterBoutiqueId.value != null &&
          p.boutiqueId != filterBoutiqueId.value) {
        return false;
      }
      if (filterCategorieId.value != null &&
          p.categorieId != filterCategorieId.value) {
        return false;
      }
      if (onlyActive.value && !p.active) return false;

      if (q.isEmpty) return true;
      return p.nom.toLowerCase().contains(q) ||
          (p.codeBarre?.toLowerCase().contains(q) ?? false) ||
          (p.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int get totalVisible => filtered.length;
  int get nbActifs => _all.where((p) => p.active).length;

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String? categorieNom(String? id) {
    if (id == null) return null;
    return categories.firstWhereOrNull((c) => c.id == id)?.nom;
  }

  String deviseDe(String boutiqueId) =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId)?.devise ?? 'GNF';

  Future<void> toggleActive(ProduitModel p) async {
    try {
      await _repo.setActive(p.id, !p.active);
      Get.snackbar(
        p.active ? 'Produit désactivé' : 'Produit activé',
        p.nom,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _snackError('Erreur : $e');
    }
  }

  Future<void> confirmDelete(ProduitModel p) async {
    final used = await _repo.hasUsage(p.id, boutiqueId: p.boutiqueId);
    if (used) {
      _snackError(
        'Suppression impossible : ce produit a un historique de stock '
        'ou de ventes. Désactivez-le plutôt pour conserver les données.',
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer le produit ?'),
        content: Text(
          'Le produit « ${p.nom} » sera supprimé définitivement.\n\n'
          'Aucun mouvement de stock ni vente n\'est lié à ce produit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Get.back(result: true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repo.delete(p.id, boutiqueId: p.boutiqueId);
      Get.snackbar('Supprimé', p.nom, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      _snackError('Suppression impossible : $e');
    }
  }

  void _snackError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
    );
  }
}
