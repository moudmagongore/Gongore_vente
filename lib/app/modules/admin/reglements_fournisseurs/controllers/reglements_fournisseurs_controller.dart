import 'package:get/get.dart';

import '../../../../core/services/reglement_fournisseur_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/reglement_fournisseur_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../data/repositories/reglement_fournisseur_repository.dart';
import '../../../../data/repositories/user_repository.dart';

enum PeriodeReglementFour { aujourdhui, semaine, mois, tout }

class ReglementsFournisseursController extends GetxController {
  final ReglementFournisseurRepository _repo =
      ReglementFournisseurRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final FournisseurRepository _fournRepo = FournisseurRepository();
  final UserRepository _userRepo = UserRepository();

  final RxList<ReglementFournisseurModel> _all =
      <ReglementFournisseurModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<FournisseurModel> fournisseurs = <FournisseurModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rx<PeriodeReglementFour> periode = PeriodeReglementFour.mois.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterFournisseurId = RxnString();
  final RxnString filterUserId = RxnString();
  final Rxn<ModePaiement> filterMode = Rxn<ModePaiement>();
  final RxString search = ''.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    if (!isSuperAdmin) {
      filterBoutiqueId.value = UserController.to.boutiqueId;
    } else {
      // IMPORTANT : enregistre l'auto-select AVANT bindStream pour ne pas
      // rater la 1re émission du stream (cache Firestore).
      ever<List<BoutiqueModel>>(boutiques, (list) {
        if (filterBoutiqueId.value == null && list.isNotEmpty) {
          filterBoutiqueId.value = list.first.id;
        }
      });
    }

    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    fournisseurs.bindStream(_fournRepo.watchScoped(scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));

    _bind();
    everAll([periode, filterBoutiqueId], (_) => _bind());
  }

  void _bind() {
    isLoading.value = true;
    var scope = filterBoutiqueId.value;
    // Fallback : super-admin sans boutique sélectionnée → auto-sélection
    // de la 1re. Évite l'écran vide si l'`ever` n'a pas fait son travail.
    if ((scope == null || scope.isEmpty) &&
        isSuperAdmin &&
        boutiques.isNotEmpty) {
      scope = boutiques.first.id;
      filterBoutiqueId.value = scope;
    }
    if (scope == null || scope.isEmpty) {
      _all.value = [];
      isLoading.value = false;
      return;
    }
    _all.bindStream(
      _repo.watchByBoutique(scope, after: _afterDate(periode.value)),
    );
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  DateTime? _afterDate(PeriodeReglementFour p) {
    final now = DateTime.now();
    switch (p) {
      case PeriodeReglementFour.aujourdhui:
        return DateTime(now.year, now.month, now.day);
      case PeriodeReglementFour.semaine:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case PeriodeReglementFour.mois:
        return DateTime(now.year, now.month, 1);
      case PeriodeReglementFour.tout:
        return null;
    }
  }

  // ===== Filtrage côté client =====
  List<ReglementFournisseurModel> get filtered {
    final q = search.value.trim().toLowerCase();
    return _all.where((r) {
      if (filterFournisseurId.value != null &&
          r.fournisseurId != filterFournisseurId.value) {
        return false;
      }
      if (filterUserId.value != null && r.userId != filterUserId.value) {
        return false;
      }
      if (filterMode.value != null && r.modePaiement != filterMode.value) {
        return false;
      }
      if (q.isEmpty) return true;
      if (fournisseurNom(r.fournisseurId).toLowerCase().contains(q)) {
        return true;
      }
      if (userNom(r.userId).toLowerCase().contains(q)) return true;
      return (r.note?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ===== Stats =====
  double get totalVerse => filtered.fold(0.0, (acc, r) => acc + r.montant);
  int get nbReglements => filtered.length;

  // ===== Helpers =====
  String fournisseurNom(String id) =>
      fournisseurs.firstWhereOrNull((f) => f.id == id)?.nom ?? '—';

  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  FournisseurModel? fournisseurById(String id) =>
      fournisseurs.firstWhereOrNull((f) => f.id == id);

  Future<void> deleteReglement(ReglementFournisseurModel r) async {
    try {
      await _repo.deleteAndRestore(r.id);
      Get.snackbar(
        'Règlement supprimé',
        'Le solde du fournisseur a été réajusté.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Suppression impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Réimprime le reçu d'un règlement existant.
  Future<void> reimprimerRecu(ReglementFournisseurModel r) async {
    final fournisseur = fournisseurById(r.fournisseurId) ??
        await _fournRepo.getById(r.fournisseurId);
    if (fournisseur == null) {
      Get.snackbar(
        'Erreur',
        'Fournisseur introuvable.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final boutique = boutiques.firstWhereOrNull((b) => b.id == r.boutiqueId) ??
        await _boutiqueRepo.getById(r.boutiqueId);
    if (boutique == null) {
      Get.snackbar(
        'Erreur',
        'Boutique introuvable.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final user = users.firstWhereOrNull((u) => u.id == r.userId) ??
        (r.userId.isEmpty ? null : await _userRepo.getById(r.userId));
    try {
      await ReglementFournisseurReceiptService.sharePrint(
        reglement: r,
        boutique: boutique,
        fournisseur: fournisseur,
        user: user,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impression impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
