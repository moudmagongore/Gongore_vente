import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/approvisionnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../data/repositories/user_repository.dart';

class ApproDetailController extends GetxController {
  final ApprovisionnementRepository _repo = ApprovisionnementRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final FournisseurRepository _fournRepo = FournisseurRepository();
  final UserRepository _userRepo = UserRepository();

  final Rxn<ApprovisionnementModel> appro = Rxn<ApprovisionnementModel>();
  final Rxn<BoutiqueModel> boutique = Rxn<BoutiqueModel>();
  final Rxn<FournisseurModel> fournisseur = Rxn<FournisseurModel>();
  final Rxn<UserModel> user = Rxn<UserModel>();
  final RxBool isLoading = true.obs;
  final RxBool isCanceling = false.obs;

  String? approId;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is String) {
      approId = arg;
    } else if (arg is ApprovisionnementModel) {
      approId = arg.id;
      appro.value = arg;
    } else {
      isLoading.value = false;
      return;
    }

    if (approId == null || approId!.isEmpty) {
      isLoading.value = false;
      return;
    }

    appro.bindStream(_repo.getById(approId!).asStream());
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final a = await _repo.getById(approId!);
      if (a == null) {
        isLoading.value = false;
        return;
      }
      appro.value = a;
      boutique.value = await _boutiqueRepo.getById(a.boutiqueId);
      fournisseur.value = await _fournRepo.getById(a.fournisseurId);
      if (a.userId.isNotEmpty) {
        user.value = await _userRepo.getById(a.userId);
      }
    } finally {
      isLoading.value = false;
    }
  }

  String get devise => boutique.value?.devise ?? 'GNF';

  String get fournisseurLabel => fournisseur.value?.nom ?? '—';

  bool get peutAnnuler {
    if (appro.value == null) return false;
    if (appro.value!.statut != ApproStatut.validee) return false;
    // Annulation = opération métier : VENDEUR uniquement.
    return UserController.to.isVendeur;
  }

  Future<void> confirmCancel() async {
    if (!peutAnnuler) return;

    final motifCtrl = TextEditingController();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Annuler l\'approvisionnement ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Le stock sera réduit des quantités reçues, et l\'effet sur '
              'le solde fournisseur sera inversé.\n\n'
              'L\'annulation est refusée si une partie a déjà été vendue '
              '(stock résiduel insuffisant pour rendre les unités).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motifCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif de l\'annulation *',
              ),
              autofocus: true,
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Garder'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              if (motifCtrl.text.trim().isEmpty) {
                Get.snackbar(
                  'Erreur',
                  'Le motif est obligatoire',
                  snackPosition: SnackPosition.TOP,
                );
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Annuler l\'appro'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final motif = motifCtrl.text.trim();
    final userId = UserController.to.user?.id;
    if (userId == null || motif.isEmpty) return;

    isCanceling.value = true;
    try {
      await _repo.cancel(
        approId: approId!,
        userId: userId,
        motif: motif,
      );
      Get.snackbar(
        'Appro annulé',
        'Le stock et le solde fournisseur ont été réajustés.',
        snackPosition: SnackPosition.TOP,
      );
      await _load();
    } catch (e) {
      Get.snackbar(
        'Annulation impossible',
        '$e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isCanceling.value = false;
    }
  }
}
