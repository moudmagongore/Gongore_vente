import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';

class FournisseursController extends GetxController {
  final FournisseurRepository _repo = FournisseurRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<FournisseurModel> _all = <FournisseurModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;
  final RxnString filterBoutiqueId = RxnString();

  /// false = tous, true = seulement les fournisseurs avec solde > 0
  /// (= on leur doit de l'argent).
  final RxBool onlyAvecDette = false.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    _all.bindStream(_repo.watchScoped(scope));
    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: scope, actives: true),
    );
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  List<FournisseurModel> get filtered {
    final q = search.value.trim().toLowerCase();
    return _all.where((f) {
      if (filterBoutiqueId.value != null &&
          f.boutiqueId != filterBoutiqueId.value) {
        return false;
      }
      if (onlyAvecDette.value && f.solde <= 0) return false;

      if (q.isEmpty) return true;
      return f.nom.toLowerCase().contains(q) ||
          (f.telephone?.toLowerCase().contains(q) ?? false) ||
          (f.email?.toLowerCase().contains(q) ?? false);
    }).toList()
      // Plus récent en haut
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
  }

  int get total => _all.length;
  /// Total de ce que la boutique doit à ses fournisseurs (somme des
  /// soldes positifs).
  double get detteTotale =>
      _all.fold(0, (acc, f) => acc + (f.solde > 0 ? f.solde : 0));

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  Future<void> confirmDelete(FournisseurModel f) async {
    final used = await _repo.hasUsage(f.id, boutiqueId: f.boutiqueId);
    if (used) {
      _snackError(
        'Suppression impossible : ce fournisseur a des approvisionnements '
        'ou règlements enregistrés. Conservez l\'historique pour la '
        'traçabilité.',
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer ce fournisseur ?'),
        content: Text(
          'Le fournisseur « ${f.nom} » sera supprimé définitivement.\n\n'
          'Aucun appro ni règlement n\'est lié à ce fournisseur.',
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
      await _repo.delete(f.id);
      Get.snackbar('Supprimé', f.nom, snackPosition: SnackPosition.TOP);
    } catch (e) {
      _snackError('Suppression impossible : $e');
    }
  }

  void _snackError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
    );
  }
}
