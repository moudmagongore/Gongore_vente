import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/reglement_fournisseur_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/reglement_fournisseur_model.dart';
import '../../../../data/repositories/approvisionnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../data/repositories/reglement_fournisseur_repository.dart';
import '../../../../data/repositories/user_repository.dart';

/// Charge et expose les données d'une fiche fournisseur : infos,
/// approvisionnements, règlements fournisseurs, statistiques.
class FournisseurDetailController extends GetxController {
  final FournisseurRepository _fournRepo = FournisseurRepository();
  final ApprovisionnementRepository _approRepo =
      ApprovisionnementRepository();
  final ReglementFournisseurRepository _reglementRepo =
      ReglementFournisseurRepository();

  final Rxn<FournisseurModel> fournisseur = Rxn<FournisseurModel>();
  final RxList<ApprovisionnementModel> approvisionnements =
      <ApprovisionnementModel>[].obs;
  final RxList<ReglementFournisseurModel> reglements =
      <ReglementFournisseurModel>[].obs;
  final RxBool isLoading = true.obs;

  String? _fournisseurId;
  String get fournisseurId => _fournisseurId ?? '';

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FournisseurModel) {
      _fournisseurId = arg.id;
      fournisseur.value = arg;
    } else if (arg is String) {
      _fournisseurId = arg;
    } else {
      isLoading.value = false;
      return;
    }

    if (_fournisseurId == null || _fournisseurId!.isEmpty) {
      isLoading.value = false;
      return;
    }

    // Stream live du fournisseur (solde + hasOperations à jour
    // automatiquement après un appro / règlement).
    fournisseur.bindStream(_fournRepo.watchById(_fournisseurId!));

    // Streams appros & règlements scopés à ce fournisseur
    approvisionnements.bindStream(
      _approRepo.watchAll(
        boutiqueId: fournisseur.value?.boutiqueId,
        fournisseurId: _fournisseurId,
      ),
    );

    final boutiqueId = fournisseur.value?.boutiqueId ?? '';
    reglements.bindStream(_reglementRepo.watchByFournisseur(
      _fournisseurId!,
      boutiqueId: boutiqueId,
    ));
    debounce(reglements, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  // ===== Stats =====
  List<ApprovisionnementModel> get _validees =>
      approvisionnements.where((a) => a.statut == ApproStatut.validee).toList();

  int get nbAppros => _validees.length;

  double get totalAchete =>
      _validees.fold(0.0, (acc, a) => acc + a.total);

  /// Total déjà versé (montants payés + règlements standalone).
  double get totalVerse {
    double sum = 0;
    for (final a in _validees) {
      sum += a.montantPaye;
    }
    for (final r in reglements) {
      sum += r.montant;
    }
    return sum;
  }

  bool get isAdminOrSuper => UserController.to.isAnyAdmin;

  /// Réimprime le reçu d'un règlement fournisseur existant.
  Future<void> reimprimerRecuReglement(
    ReglementFournisseurModel r,
  ) async {
    final f = fournisseur.value;
    if (f == null) return;
    final boutique = await BoutiqueRepository().getById(r.boutiqueId);
    if (boutique == null) {
      Get.snackbar(
        'Erreur',
        'Boutique introuvable.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final user = r.userId.isEmpty
        ? null
        : await UserRepository().getById(r.userId);
    try {
      await ReglementFournisseurReceiptService.sharePrint(
        reglement: r,
        boutique: boutique,
        fournisseur: f,
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

  // ===== Suppression d'un règlement (correction d'erreur de saisie) =====
  Future<void> confirmDeleteReglement(ReglementFournisseurModel r) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer ce règlement ?'),
        content: const Text(
          'Le montant sera ré-ajouté au solde du fournisseur. Action '
          'réservée aux corrections d\'erreur de saisie.',
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
      await _reglementRepo.deleteAndRestore(r.id);
      Get.snackbar(
        'Règlement supprimé',
        'Le solde a été réajusté.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Suppression impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    }
  }
}
