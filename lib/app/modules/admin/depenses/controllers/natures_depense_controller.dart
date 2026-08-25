import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/nature_depense_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/nature_depense_repository.dart';

/// Liste des natures de dépense (référentiel). Écran réservé à l'admin de
/// boutique et au super-admin : le gestionnaire consomme ce référentiel
/// depuis le formulaire de dépense, il ne le modifie pas.
class NaturesDepenseController extends GetxController {
  final NatureDepenseRepository _repo = NatureDepenseRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<NatureDepenseModel> _all = <NatureDepenseModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;

  /// false = on cache les natures désactivées, true = on les inclut.
  final RxBool inclureInactives = false.obs;

  /// Filtre boutique (super-admin uniquement). null = toutes.
  final RxnString filterBoutiqueId = RxnString();

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    _all.bindStream(_repo.watchScoped(scope));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  String boutiqueNom(String? id) {
    if (id == null || id.isEmpty) return '—';
    return boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';
  }

  List<NatureDepenseModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final boutiqueFilter = filterBoutiqueId.value;
    return _all.where((n) {
      if (!inclureInactives.value && !n.active) return false;
      if (boutiqueFilter != null && n.boutiqueId != boutiqueFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return n.nom.toLowerCase().contains(q) ||
          (n.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int get nbActives => _all.where((n) => n.active).length;

  Future<void> toggleActive(NatureDepenseModel n) async {
    try {
      await _repo.setActive(n.id, !n.active);
      Get.snackbar(
        n.active ? 'Nature désactivée' : 'Nature réactivée',
        n.active
            ? '« ${n.nom} » n\'est plus proposée à la saisie.'
            : '« ${n.nom} » est de nouveau disponible.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _snackError('Modification impossible : $e');
    }
  }

  /// Suppression bloquée dès qu'une dépense référence la nature : on
  /// propose alors la désactivation, qui préserve l'historique.
  Future<void> confirmDelete(NatureDepenseModel n) async {
    final used = await _repo.hasUsage(n.id, boutiqueId: n.boutiqueId);
    if (used) {
      final desactiver = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Suppression impossible'),
          content: Text(
            'Des dépenses sont rattachées à « ${n.nom} ». '
            'La supprimer casserait l\'historique.\n\n'
            'Vous pouvez la désactiver : elle disparaît du formulaire de '
            'saisie mais reste lisible dans les dépenses passées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Annuler'),
            ),
            if (n.active)
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Désactiver'),
              ),
          ],
        ),
      );
      if (desactiver == true) await toggleActive(n);
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer la nature ?'),
        content: Text(
          'La nature « ${n.nom} » sera supprimée.\n\n'
          'Aucune dépense n\'y est rattachée.',
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
      await _repo.delete(n.id);
      Get.snackbar('Supprimée', n.nom, snackPosition: SnackPosition.TOP);
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
    );
  }
}
