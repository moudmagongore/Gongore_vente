import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/boutique_repository.dart';

class BoutiquesController extends GetxController {
  final BoutiqueRepository _repo = BoutiqueRepository();

  /// null = toutes, true = actives, false = inactives
  final Rxn<bool> filterActive = Rxn<bool>();
  final RxString search = ''.obs;

  final RxList<BoutiqueModel> _all = <BoutiqueModel>[].obs;
  final RxBool isLoading = true.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    _bind();
  }

  void _bind() {
    isLoading.value = true;
    _all.bindStream(
      _repo.watchScoped(scope: UserController.to.scopeBoutiqueId),
    );
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  /// Liste filtrée selon le rôle et les filtres UI.
  List<BoutiqueModel> get filtered {
    final scope = UserController.to.scopeBoutiqueId;
    final q = search.value.trim().toLowerCase();
    return _all.where((b) {
      // Admin de boutique : ne voit QUE sa boutique
      if (scope != null && b.id != scope) return false;
      if (filterActive.value != null && b.active != filterActive.value) {
        return false;
      }
      if (q.isEmpty) return true;
      return b.nom.toLowerCase().contains(q) ||
          (b.adresse?.toLowerCase().contains(q) ?? false) ||
          (b.telephone?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int get totalCount {
    final scope = UserController.to.scopeBoutiqueId;
    if (scope != null) return _all.where((b) => b.id == scope).length;
    return _all.length;
  }

  int get activeCount {
    final scope = UserController.to.scopeBoutiqueId;
    final list = scope == null
        ? _all
        : _all.where((b) => b.id == scope);
    return list.where((b) => b.active).length;
  }

  void setFilter(bool? value) => filterActive.value = value;

  Future<void> toggleActive(BoutiqueModel b) async {
    if (!isSuperAdmin) {
      _snackError('Action réservée au super-admin');
      return;
    }
    try {
      await _repo.setActive(b.id, !b.active);
      Get.snackbar(
        b.active ? 'Boutique désactivée' : 'Boutique activée',
        b.nom,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _snackError('Impossible de modifier le statut : $e');
    }
  }

  Future<void> confirmDelete(BoutiqueModel b) async {
    if (!isSuperAdmin) {
      _snackError('Action réservée au super-admin');
      return;
    }
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer la boutique ?'),
        content: Text(
          '⚠️ La boutique « ${b.nom} » sera supprimée DÉFINITIVEMENT '
          'avec TOUTES ses données :\n\n'
          '• Tous les utilisateurs (admins + gestionnaires)\n'
          '• Tous les produits et catégories\n'
          '• Toutes les ventes et tous les clients\n\n'
          'Cette action est IRRÉVERSIBLE.\n\n'
          '💡 Astuce : préférez la désactiver pour conserver les données.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Get.back(result: true),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Loader pendant la cascade
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final res = await _repo.deleteCascade(b.id);
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Boutique supprimée',
        '${res.users} users, ${res.produits} produits, '
        '${res.ventes} ventes, ${res.clients} clients.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      _snackError('Suppression incomplète : $e');
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
