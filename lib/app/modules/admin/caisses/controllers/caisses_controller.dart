import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/caisse_contexte.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/caisse_repository.dart';
import '../../../../data/repositories/user_repository.dart';

/// Liste des caisses. Écran partagé :
/// - admin et super-admin : paramétrage complet ;
/// - gestionnaire : lecture seule des caisses qui lui sont accessibles
///   (entrée « Mes caisses » du drawer).
class CaissesController extends GetxController {
  final CaisseRepository _repo = CaisseRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();

  final RxList<CaisseModel> _all = <CaisseModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;

  /// false = on cache les caisses désactivées, true = on les inclut.
  final RxBool inclureInactives = false.obs;

  /// Filtre boutique (super-admin uniquement). null = toutes.
  final RxnString filterBoutiqueId = RxnString();

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  /// Seul l'admin paramètre les caisses. Le gestionnaire ne voit que les
  /// soldes, sans bouton de création ni menu d'action.
  bool get canManage => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final uc = UserController.to;
    final scope = uc.scopeBoutiqueId;
    _all.bindStream(CaisseContexte.watchCaisses(scope));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    if (canManage) {
      users.bindStream(_userRepo.watchScoped(scope: scope));
    }
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  String boutiqueNom(String? id) {
    if (id == null || id.isEmpty) return '—';
    return boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';
  }

  /// Noms des gestionnaires ayant accès à la caisse. Un uid devenu
  /// introuvable (compte supprimé) est ignoré plutôt qu'affiché comme
  /// identifiant brut.
  List<String> gestionnaireNoms(CaisseModel c) {
    return c.gestionnaireIds
        .map((id) => users.firstWhereOrNull((u) => u.id == id)?.nom)
        .whereType<String>()
        .toList();
  }

  List<CaisseModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final boutiqueFilter = filterBoutiqueId.value;
    return _all.where((c) {
      if (!inclureInactives.value && !c.active) return false;
      if (boutiqueFilter != null && c.boutiqueId != boutiqueFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.nom.toLowerCase().contains(q);
    }).toList();
  }

  int get nbActives => _all.where((c) => c.active).length;

  /// Caisses actives visibles par l'utilisateur, filtre boutique appliqué.
  ///
  /// Sert aux transferts et aux mouvements manuels : pour un gestionnaire,
  /// le stream ne contient déjà que ses caisses accessibles (RG-21).
  List<CaisseModel> get caissesActives {
    final boutiqueFilter = filterBoutiqueId.value;
    return _all.where((c) {
      if (!c.active) return false;
      if (boutiqueFilter != null && c.boutiqueId != boutiqueFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Toutes les caisses visibles, désactivées comprises : une correction
  /// doit pouvoir viser une caisse qu'on a cessé d'utiliser.
  List<CaisseModel> get caisses => _all.toList();

  /// Un transfert exige deux caisses accessibles (RG-20, RG-21).
  bool get peutTransferer => caissesActives.length >= 2;

  /// Apports, retraits et corrections sont réservés à l'admin (RG-25).
  bool get peutMouvementManuel => canManage && _all.isNotEmpty;

  /// Total des caisses affichées. Il suit donc la recherche et les
  /// filtres : c'est voulu, l'utilisateur veut le total de ce qu'il voit.
  double get soldeTotal =>
      filtered.fold<double>(0, (acc, c) => acc + c.solde);

  Future<void> toggleActive(CaisseModel c) async {
    try {
      await _repo.setActive(c.id, !c.active);
      Get.snackbar(
        c.active ? 'Caisse désactivée' : 'Caisse réactivée',
        c.active
            ? '« ${c.nom} » n\'est plus proposée dans les opérations. '
                'Son solde et ses mouvements restent consultables.'
            : '« ${c.nom} » est de nouveau disponible.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _snackError('Modification impossible : $e');
    }
  }

  /// Suppression possible uniquement si la caisse n'a jamais servi
  /// (RG-7) ; sinon on propose la désactivation, qui préserve l'historique.
  Future<void> confirmDelete(CaisseModel c) async {
    if (c.hasMouvements) {
      final desactiver = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Suppression impossible'),
          content: Text(
            '« ${c.nom} » a des mouvements : la supprimer effacerait '
            'une partie de l\'historique de trésorerie.\n\n'
            'Vous pouvez la désactiver : elle disparaît des opérations '
            'mais reste lisible dans les relevés et les rapports.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Annuler'),
            ),
            if (c.active)
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Désactiver'),
              ),
          ],
        ),
      );
      if (desactiver == true) await toggleActive(c);
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer la caisse ?'),
        content: Text(
          'La caisse « ${c.nom} » sera supprimée.\n\n'
          'Elle n\'a enregistré aucun mouvement.',
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
      // Cas limite : un premier mouvement est arrivé pendant que l'écran
      // était ouvert. Le repository refait le contrôle en transaction.
      _snackError('$e');
    }
  }

  String money(double v) => Fmt.money(v, currency: 'GNF');

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
