import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

class VenteDetailController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();

  final Rxn<VenteModel> vente = Rxn<VenteModel>();
  final Rxn<BoutiqueModel> boutique = Rxn<BoutiqueModel>();
  final Rxn<UserModel> vendeur = Rxn<UserModel>();
  final RxBool isLoading = true.obs;
  final RxBool isCanceling = false.obs;

  String? get venteId => Get.arguments as String?;

  @override
  void onInit() {
    super.onInit();
    if (venteId == null) return;
    vente.bindStream(_venteRepo.watchOne(venteId!));
    ever(vente, (VenteModel? v) async {
      if (v == null) return;
      isLoading.value = false;
      boutique.value = await _boutiqueRepo.getById(v.boutiqueId);
      vendeur.value = await _userRepo.getById(v.vendeurId);
    });
  }

  String get devise => boutique.value?.devise ?? 'GNF';

  bool get peutAnnuler {
    if (vente.value == null) return false;
    if (vente.value!.statut != VenteStatut.validee) return false;
    return UserController.to.isAdmin; // seuls les admins annulent
  }

  Future<void> confirmCancel() async {
    if (!peutAnnuler) return;

    final motifCtrl = TextEditingController();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Annuler la vente ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Le stock des articles vendus sera restitué.\n'
              'Cette action est tracée dans l\'historique.',
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
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Annuler la vente'),
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
      await _venteRepo.cancel(
        venteId: venteId!,
        userId: userId,
        motif: motif,
      );
      Get.snackbar(
        'Vente annulée',
        'Le stock a été restitué',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Annulation impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isCanceling.value = false;
    }
  }
}
