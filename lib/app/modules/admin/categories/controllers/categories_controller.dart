import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';

class CategoriesController extends GetxController {
  final CategorieRepository _repo = CategorieRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<CategorieModel> _all = <CategorieModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;

  /// Filtre boutique (super-admin uniquement). null = toutes.
  final RxnString filterBoutiqueId = RxnString();

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    // Super-admin voit toutes ; admin de boutique : filtre côté Firestore
    _all.bindStream(_repo.watchAll(boutiqueId: scope));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  String boutiqueNom(String? id) {
    if (id == null || id.isEmpty) return '—';
    return boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';
  }

  List<CategorieModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final boutiqueFilter = filterBoutiqueId.value;
    final base = _all.where((c) {
      // Filtre boutique (super-admin)
      if (boutiqueFilter != null && c.boutiqueId != boutiqueFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.nom.toLowerCase().contains(q) ||
          (c.description?.toLowerCase().contains(q) ?? false);
    }).toList();
    // Plus récent en haut (les anciens documents sans createdAt finissent en bas)
    return base
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
  }

  int get total => _all.length;

  Future<void> confirmDelete(CategorieModel c) async {
    final used =
        await _repo.hasUsage(c.id, boutiqueId: c.boutiqueId ?? '');
    if (used) {
      Get.snackbar(
        'Suppression impossible',
        'Cette catégorie est utilisée par au moins un produit. '
        'Réaffectez ou supprimez d\'abord les produits concernés.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          'La catégorie « ${c.nom} » sera supprimée.\n\n'
          'Aucun produit n\'est rattaché à cette catégorie.',
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
      await _repo.delete(c.id);
      Get.snackbar('Supprimée', c.nom, snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Suppression impossible : $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    }
  }
}
