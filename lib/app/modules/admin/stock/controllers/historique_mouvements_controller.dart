import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/stock_repository.dart';

class HistoriqueMouvementsController extends GetxController {
  final StockRepository _stockRepo = StockRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final ProduitRepository _produitRepo = ProduitRepository();

  final RxnString boutiqueId = RxnString();
  final RxList<MouvementStockModel> mouvements = <MouvementStockModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: UserController.to.scopeBoutiqueId),
    );

    // Si une boutique est passée en argument
    final arg = Get.arguments;
    if (arg is String) boutiqueId.value = arg;
    if (boutiqueId.value == null) {
      // Rebind quand les boutiques arrivent
      ever<List<BoutiqueModel>>(boutiques, (list) {
        if (boutiqueId.value == null && list.isNotEmpty) {
          boutiqueId.value = list.first.id;
        }
      });
    }

    ever(boutiqueId, (String? id) {
      if (id == null) return;
      isLoading.value = true;
      mouvements.bindStream(_stockRepo.watchMouvements(boutiqueId: id));
      produits.bindStream(_produitRepo.watchAll(boutiqueId: id));
      debounce(mouvements, (_) => isLoading.value = false,
          time: const Duration(milliseconds: 200));
    });
  }

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String produitNom(String id) =>
      produits.firstWhereOrNull((p) => p.id == id)?.nom ?? '—';
}
