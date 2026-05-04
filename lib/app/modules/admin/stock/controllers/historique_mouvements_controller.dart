import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/mouvement_stock_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/user_repository.dart';

enum PeriodeMouvement { aujourdhui, semaine, mois, tout }

class HistoriqueMouvementsController extends GetxController {
  final MouvementStockRepository _repo = MouvementStockRepository();
  final ProduitRepository _produitRepo = ProduitRepository();
  final UserRepository _userRepo = UserRepository();

  final RxList<MouvementStockModel> _all = <MouvementStockModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rx<PeriodeMouvement> periode = PeriodeMouvement.mois.obs;
  final RxnString filterProduitId = RxnString();
  final RxnString filterUserId = RxnString();
  final Rxn<MouvementStockType> filterType = Rxn<MouvementStockType>();
  final RxString search = ''.obs;

  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    produits.bindStream(_produitRepo.watchAll(boutiqueId: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));
    _bind();
    everAll([periode], (_) => _bind());
  }

  void _bind() {
    isLoading.value = true;
    final scope = UserController.to.scopeBoutiqueId;
    if (scope == null || scope.isEmpty) {
      // Super-admin sans filtre boutique : on n'affiche rien (la query
      // sans boutiqueId échouerait sur les rules pour les non-super-admin
      // et serait trop large même pour eux). Le cas est rare.
      _all.value = [];
      isLoading.value = false;
      return;
    }
    _all.bindStream(_repo.watchByBoutique(
      scope,
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
