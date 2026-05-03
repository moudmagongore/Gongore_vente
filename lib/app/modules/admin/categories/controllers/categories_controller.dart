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
    if (q.isEmpty) return _all.toList();
    return _all
        .where((c) =>
            c.nom.toLowerCase().contains(q) ||
            (c.description?.toLowerCase().contains(q) ?? false))
        .toList();
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
        snackPosition: SnackPosition.BOTTOM,
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
      Get.snackbar('Supprimée', c.nom, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Suppression impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    }
  }
}
