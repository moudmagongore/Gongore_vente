import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/client_repository.dart';

class ClientsController extends GetxController {
  final ClientRepository _repo = ClientRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<ClientModel> _all = <ClientModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;
  final RxnString filterBoutiqueId = RxnString();

  /// false = tous, true = seulement les clients avec solde > 0
  final RxBool onlyAvecDette = false.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

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

  List<ClientModel> get filtered {
    final q = search.value.trim().toLowerCase();
    return _all.where((c) {
      if (filterBoutiqueId.value != null &&
          c.boutiqueId != filterBoutiqueId.value) {
        return false;
      }
      if (onlyAvecDette.value && c.solde <= 0) return false;

      if (q.isEmpty) return true;
      return c.nom.toLowerCase().contains(q) ||
          (c.telephone?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int get total => _all.length;
  double get detteTotale =>
      _all.fold(0, (acc, c) => acc + (c.solde > 0 ? c.solde : 0));

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  Future<void> confirmDelete(ClientModel c) async {
    // Vérifie d'abord qu'il n'y a aucune opération liée.
    final used = await _repo.hasUsage(c.id, boutiqueId: c.boutiqueId);
    if (used) {
      _snackError(
        'Suppression impossible : ce client a des ventes ou règlements '
        'enregistrés. Conservez l\'historique pour la traçabilité.',
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: Text(
          'Le client « ${c.nom} » sera supprimé définitivement.\n\n'
          'Aucune vente ni règlement n\'est lié à ce client.',
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
      Get.snackbar('Supprimé', c.nom, snackPosition: SnackPosition.TOP);
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
