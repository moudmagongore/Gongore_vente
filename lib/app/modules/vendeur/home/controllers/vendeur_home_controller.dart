import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

class VendeurHomeController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<VenteModel> ventesAujourdhui = <VenteModel>[].obs;
  final Rxn<BoutiqueModel> boutique = Rxn<BoutiqueModel>();
  final RxBool isLoading = true.obs;

  String get nomVendeur => UserController.to.user?.nom ?? '';
  String get devise => boutique.value?.devise ?? 'GNF';

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final user = UserController.to.user;
    if (user == null) return;

    if (user.boutiqueId != null && user.boutiqueId!.isNotEmpty) {
      boutique.value = await _boutiqueRepo.getById(user.boutiqueId!);
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    ventesAujourdhui.bindStream(
      _venteRepo.watchAll(
        vendeurId: user.id,
        boutiqueId: user.boutiqueId,
        after: startOfDay,
      ),
    );
    debounce(ventesAujourdhui, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  // Stats du jour (validées seulement)
  List<VenteModel> get _validees =>
      ventesAujourdhui.where((v) => v.statut == VenteStatut.validee).toList();

  int get nbVentesJour => _validees.length;

  double get caJour => _validees.fold(0.0, (acc, v) => acc + v.total);

  int get nbArticlesVendus =>
      _validees.fold(0, (acc, v) => acc + v.nbArticles);
}
