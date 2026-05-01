import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

enum PeriodeFiltre { aujourdhui, semaine, mois, tout }

class VentesController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();

  final RxList<VenteModel> _all = <VenteModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> vendeurs = <UserModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterVendeurId = RxnString();
  final Rxn<ModePaiement> filterModePaiement = Rxn<ModePaiement>();
  final RxBool inclureAnnulees = false.obs;
  final Rx<PeriodeFiltre> periode = PeriodeFiltre.tout.obs;

  bool get isAdmin => UserController.to.isAdmin;
  bool get isVendeur => UserController.to.isVendeur;
  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  /// Désigne quel rôle a accès à la vue : super-admin, admin de boutique
  /// (filtre auto sur sa boutique), ou vendeur (filtre auto sur ses ventes).
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    vendeurs.bindStream(_userRepo.watchScoped(scope: scope));

    if (isVendeur) {
      // Vendeur : ne voit que ses propres ventes
      final user = UserController.to.user;
      filterVendeurId.value = user?.id;
      filterBoutiqueId.value = user?.boutiqueId;
    } else if (isAdmin) {
      // Admin de boutique : ne voit que les ventes de sa boutique
      filterBoutiqueId.value = UserController.to.boutiqueId;
    }

    _bind();

    // Réagir aux changements de filtre
    everAll([filterBoutiqueId, filterVendeurId, periode], (_) => _bind());
  }

  void _bind() {
    isLoading.value = true;
    DateTime? after;
    final now = DateTime.now();
    switch (periode.value) {
      case PeriodeFiltre.aujourdhui:
        after = DateTime(now.year, now.month, now.day);
        break;
      case PeriodeFiltre.semaine:
        after = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        break;
      case PeriodeFiltre.mois:
        after = DateTime(now.year, now.month, 1);
        break;
      case PeriodeFiltre.tout:
        after = null;
        break;
    }
    _all.bindStream(_venteRepo.watchAll(
      boutiqueId: filterBoutiqueId.value,
      vendeurId: filterVendeurId.value,
      after: after,
    ));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  List<VenteModel> get filtered {
    return _all.where((v) {
      if (!inclureAnnulees.value && v.statut == VenteStatut.annulee) {
        return false;
      }
      if (filterModePaiement.value != null &&
          v.modePaiement != filterModePaiement.value) {
        return false;
      }
      return true;
    }).toList();
  }

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String vendeurNom(String id) =>
      vendeurs.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  String deviseDe(String boutiqueId) =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId)?.devise ?? 'GNF';

  // ======== Stats ========
  double get caTotal => filtered
      .where((v) => v.statut == VenteStatut.validee)
      .fold(0.0, (acc, v) => acc + v.total);

  int get nbVentesValidees =>
      filtered.where((v) => v.statut == VenteStatut.validee).length;
}
