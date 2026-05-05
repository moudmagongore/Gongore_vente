import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/appro_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart' show ModePaiement;
import '../../../../data/repositories/approvisionnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../data/repositories/user_repository.dart';

enum PeriodeAppro { aujourdhui, semaine, mois, personnalise, tout }

class ApprosController extends GetxController {
  final ApprovisionnementRepository _repo = ApprovisionnementRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();
  final FournisseurRepository _fournRepo = FournisseurRepository();

  final RxList<ApprovisionnementModel> _all =
      <ApprovisionnementModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<FournisseurModel> fournisseurs = <FournisseurModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterUserId = RxnString();
  final RxnString filterFournisseurId = RxnString();
  final Rxn<ModePaiement> filterModePaiement = Rxn<ModePaiement>();
  final RxBool inclureAnnulees = false.obs;
  final RxBool onlyAvecCredit = false.obs;
  final RxString search = ''.obs;
  final Rx<PeriodeAppro> periode = PeriodeAppro.mois.obs;
  final Rxn<DateTime> customDebut = Rxn<DateTime>();
  final Rxn<DateTime> customFin = Rxn<DateTime>();

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;
  bool get isVendeur => UserController.to.isVendeur;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));
    fournisseurs.bindStream(_fournRepo.watchScoped(scope));

    if (scope != null) {
      filterBoutiqueId.value = scope;
    }

    _bind();
    everAll(
      [filterBoutiqueId, filterUserId, periode, customDebut, customFin],
      (_) => _bind(),
    );
  }

  void _bind() {
    isLoading.value = true;
    DateTime? after;
    final now = DateTime.now();
    switch (periode.value) {
      case PeriodeAppro.aujourdhui:
        after = DateTime(now.year, now.month, now.day);
        break;
      case PeriodeAppro.semaine:
        after = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        break;
      case PeriodeAppro.mois:
        after = DateTime(now.year, now.month, 1);
        break;
      case PeriodeAppro.personnalise:
        final d = customDebut.value;
        after = d == null ? null : DateTime(d.year, d.month, d.day);
        break;
      case PeriodeAppro.tout:
        after = null;
        break;
    }
    _all.bindStream(_repo.watchAll(
      boutiqueId: filterBoutiqueId.value,
      userId: filterUserId.value,
      after: after,
    ));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  List<ApprovisionnementModel> get filtered {
    final q = search.value.trim().toLowerCase();
    DateTime? avant;
    if (periode.value == PeriodeAppro.personnalise &&
        customFin.value != null) {
      final f = customFin.value!;
      avant = DateTime(f.year, f.month, f.day, 23, 59, 59, 999);
    }
    return _all.where((a) {
      if (avant != null && a.date.isAfter(avant)) return false;
      if (!inclureAnnulees.value && a.statut == ApproStatut.annulee) {
        return false;
      }
      if (filterModePaiement.value != null &&
          a.modePaiement != filterModePaiement.value) {
        return false;
      }
      if (filterFournisseurId.value != null &&
          a.fournisseurId != filterFournisseurId.value) {
        return false;
      }
      if (onlyAvecCredit.value) {
        if (a.statut != ApproStatut.validee) return false;
        if (a.resteAPayer <= 0) return false;
      }

      if (q.isEmpty) return true;
      final num = a.numeroAffichage.toLowerCase();
      if (num.contains(q)) return true;
      final fName = fournisseurNom(a.fournisseurId).toLowerCase();
      if (fName.contains(q)) return true;
      final uName = userNom(a.userId).toLowerCase();
      if (uName.contains(q)) return true;
      return false;
    }).toList();
  }

  // ===== Helpers =====
  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';
  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';
  String fournisseurNom(String id) =>
      fournisseurs.firstWhereOrNull((f) => f.id == id)?.nom ?? '—';
  FournisseurModel? fournisseurById(String id) =>
      fournisseurs.firstWhereOrNull((f) => f.id == id);
  String deviseDe(String boutiqueId) =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId)?.devise ?? 'GNF';

  // ===== Stats =====
  List<ApprovisionnementModel> get _validees =>
      filtered.where((a) => a.statut == ApproStatut.validee).toList();
  double get totalAchats =>
      _validees.fold(0.0, (acc, a) => acc + a.total);
  int get nbAppros => _validees.length;
  double get detteEnCours =>
      _validees.fold(0.0, (acc, a) => acc + a.resteAPayer);

  // ===== Réimpression =====
  Future<void> reimprimerRecu(ApprovisionnementModel a) async {
    final boutique =
        boutiques.firstWhereOrNull((b) => b.id == a.boutiqueId) ??
            await _boutiqueRepo.getById(a.boutiqueId);
    if (boutique == null) {
      _snackError('Boutique introuvable');
      return;
    }
    final fournisseur =
        fournisseurs.firstWhereOrNull((f) => f.id == a.fournisseurId) ??
            await _fournRepo.getById(a.fournisseurId);
    if (fournisseur == null) {
      _snackError('Fournisseur introuvable');
      return;
    }
    final user = users.firstWhereOrNull((u) => u.id == a.userId) ??
        (a.userId.isEmpty ? null : await _userRepo.getById(a.userId));
    try {
      await ApproReceiptService.sharePrint(
        appro: a,
        boutique: boutique,
        fournisseur: fournisseur,
        user: user,
      );
    } catch (e) {
      _snackError('Impression impossible : $e');
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
