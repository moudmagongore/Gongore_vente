import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/abonnement_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/abonnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';

/// Vue lecture seule pour un admin de boutique : statut d'abonnement de SA
/// boutique + historique des paiements la concernant.
class MonAbonnementController extends GetxController {
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final AbonnementRepository _aboRepo = AbonnementRepository();

  final RxList<BoutiqueModel> _boutiques = <BoutiqueModel>[].obs;
  final RxList<AbonnementModel> historique = <AbonnementModel>[].obs;
  final RxBool isLoading = true.obs;

  String? get _boutiqueId => UserController.to.user?.boutiqueId;

  BoutiqueModel? get boutique => _boutiques.firstOrNull;

  @override
  void onInit() {
    super.onInit();
    final bid = _boutiqueId;
    if (bid == null || bid.isEmpty) {
      isLoading.value = false;
      return;
    }
    _boutiques.bindStream(_boutiqueRepo.watchScoped(scope: bid));
    historique.bindStream(_aboRepo.watchByBoutique(bid));
    debounce(_boutiques, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }
}
