import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/mouvement_stock_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/user_repository.dart';

enum PeriodeMouvement { aujourdhui, semaine, mois, tout }

class HistoriqueMouvementsController extends GetxController {
  final MouvementStockRepository _repo = MouvementStockRepository();
  final ProduitRepository _produitRepo = ProduitRepository();
  final UserRepository _userRepo = UserRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<MouvementStockModel> _all = <MouvementStockModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rx<PeriodeMouvement> periode = PeriodeMouvement.mois.obs;
  final RxnString filterProduitId = RxnString();
  final RxnString filterUserId = RxnString();
  final Rxn<MouvementStockType> filterType = Rxn<MouvementStockType>();
  /// Filtre boutique (super-admin uniquement). Requis pour afficher des
  /// mouvements (la query est scopée par boutique côté repository).
  final RxnString filterBoutiqueId = RxnString();
  final RxString search = ''.obs;

  bool get isAnyAdmin => UserController.to.isAnyAdmin;
  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    produits.bindStream(_produitRepo.watchAll(boutiqueId: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    // Pour non-super-admin : verrouille le filtre sur leur boutique active.
    if (!isSuperAdmin && scope != null && scope.isNotEmpty) {
      filterBoutiqueId.value = scope;
    }
    _bind();
    everAll([periode, filterBoutiqueId], (_) => _bind());
  }

  void _bind() {
    isLoading.value = true;
    // Pour super-admin : utilise le filtre boutique manuel.
    // Pour admin/vendeur : déjà verrouillé sur leur boutique active.
    final boutiqueId =
        filterBoutiqueId.value ?? UserController.to.scopeBoutiqueId;
    if (boutiqueId == null || boutiqueId.isEmpty) {
      // Super-admin n'a pas encore choisi de boutique → liste vide.
      _all.value = [];
      isLoading.value = false;
      return;
    }
    _all.bindStream(_repo.watchByBoutique(
      boutiqueId,
      after: _afterDate(periode.value),
      limit: 500,
    ));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  DateTime? _afterDate(PeriodeMouvement p) {
    final now = DateTime.now();
    switch (p) {
      case PeriodeMouvement.aujourdhui:
        return DateTime(now.year, now.month, now.day);
      case PeriodeMouvement.semaine:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case PeriodeMouvement.mois:
        return DateTime(now.year, now.month, 1);
      case PeriodeMouvement.tout:
        return null;
    }
  }

  List<MouvementStockModel> get filtered {
    final q = search.value.trim().toLowerCase();
    return _all.where((m) {
      if (filterProduitId.value != null &&
          m.produitId != filterProduitId.value) {
        return false;
      }
      if (filterUserId.value != null && m.userId != filterUserId.value) {
        return false;
      }
      if (filterType.value != null && m.type != filterType.value) {
        return false;
      }
      if (q.isEmpty) return true;
      if (m.produitNom.toLowerCase().contains(q)) return true;
      if (userNom(m.userId).toLowerCase().contains(q)) return true;
      return (m.motif?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  // ===== Stats =====
  int get nbMouvements => filtered.length;
  int get nbEntrees => filtered
      .where((m) => m.type == MouvementStockType.entree)
      .length;
  int get nbSorties => filtered
      .where((m) =>
          m.type == MouvementStockType.sortie ||
          m.type == MouvementStockType.perte ||
          m.type == MouvementStockType.casse)
      .length;
  int get nbAjustements => filtered
      .where((m) => m.type == MouvementStockType.ajustement)
      .length;
}
