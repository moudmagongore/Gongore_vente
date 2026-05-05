import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/services/user_creation_service.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/user_repository.dart';

class UsersController extends GetxController {
  final UserRepository _userRepo = UserRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserCreationService _creation = UserCreationService();

  final RxList<UserModel> _all = <UserModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxBool isLoading = true.obs;

  /// null = tous, sinon role précis
  final Rxn<UserRole> filterRole = Rxn<UserRole>();

  /// null = toutes, sinon boutiqueId
  final RxnString filterBoutiqueId = RxnString();
  final RxString search = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _bind();
  }

  void _bind() {
    isLoading.value = true;
    final scope = UserController.to.scopeBoutiqueId;
    _all.bindStream(_userRepo.watchScoped(scope: scope));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  List<UserModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final scope = UserController.to.scopeBoutiqueId;
    return _all.where((u) {
      // Admin de boutique : ne voit que les vendeurs de sa boutique
      if (scope != null && u.boutiqueId != scope) return false;
      // Admin de boutique : cache les super-admins et les autres admins
      if (scope != null && u.role != UserRole.vendeur) return false;
      // Toujours cacher les super-admins aux non-super-admins
      if (!UserController.to.isSuperAdmin && u.role == UserRole.superAdmin) {
        return false;
      }
      // Cacher l'utilisateur connecté pour éviter qu'il se modifie/supprime lui-même
      if (u.id == UserController.to.user?.id) return false;

      if (filterRole.value != null && u.role != filterRole.value) return false;
      if (filterBoutiqueId.value != null &&
          u.boutiqueId != filterBoutiqueId.value) {
        return false;
      }

      if (q.isEmpty) return true;
      return u.nom.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.telephone?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int get totalVisible => filtered.length;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  int get nbAdmins {
    final scope = UserController.to.scopeBoutiqueId;
    final list = scope == null
        ? _all.where((u) => u.role != UserRole.superAdmin)
        : _all.where((u) => u.boutiqueId == scope);
    return list.where((u) => u.isAdmin).length;
  }

  int get nbVendeurs {
    final scope = UserController.to.scopeBoutiqueId;
    final list = scope == null ? _all : _all.where((u) => u.boutiqueId == scope);
    return list.where((u) => u.isVendeur).length;
  }

  String boutiqueNom(String? id) {
    if (id == null || id.isEmpty) return 'Aucune';
    return boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';
  }

  void setFilterRole(UserRole? role) => filterRole.value = role;
  void setFilterBoutique(String? id) => filterBoutiqueId.value = id;

  Future<void> toggleActive(UserModel u) async {
    try {
      await _userRepo.setActive(u.id, !u.active);
      Get.snackbar(
        u.active ? 'Compte désactivé' : 'Compte activé',
        u.nom,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _snackError('Erreur : $e');
    }
  }

  Future<void> sendPasswordReset(UserModel u) async {
    try {
      await _creation.sendPasswordResetEmail(u.email);
      Get.snackbar(
        'Email envoyé',
        'Un lien de réinitialisation a été envoyé à ${u.email}',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      _snackError('Envoi impossible : $e');
    }
  }

  Future<void> confirmDelete(UserModel u) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
          'Le compte de « ${u.nom} » sera retiré de la liste.\n\n'
          '⚠️ Le compte d\'authentification (email + mot de passe) reste '
          'actif côté Firebase. Pour le supprimer définitivement, '
          'allez sur la console Firebase → Authentication.\n\n'
          'Astuce : préférez désactiver le compte plutôt que le supprimer.',
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
      await _userRepo.deleteDoc(u.id);
      Get.snackbar('Supprimé', u.nom, snackPosition: SnackPosition.TOP);
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
