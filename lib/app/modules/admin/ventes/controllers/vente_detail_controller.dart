import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/client_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

class VenteDetailController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();
  final ClientRepository _clientRepo = ClientRepository();

  final Rxn<VenteModel> vente = Rxn<VenteModel>();
  final Rxn<BoutiqueModel> boutique = Rxn<BoutiqueModel>();
  final Rxn<UserModel> vendeur = Rxn<UserModel>();
  final Rxn<ClientModel> client = Rxn<ClientModel>();
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
      if (v.clientId != null && v.clientId!.isNotEmpty) {
        client.value = await _clientRepo.getById(v.clientId!);
      } else {
        client.value = null;
      }
    });
  }

  /// Libellé client à afficher : nom du client lié, ou nom libre,
  /// ou « Client divers » par défaut.
  String get clientLabel {
    final v = vente.value;
    if (v == null) return '—';
    if (client.value != null) return client.value!.nom;
    if (v.clientNomLibre != null && v.clientNomLibre!.isNotEmpty) {
      return v.clientNomLibre!;
    }
    return 'Client divers';
  }

  String get devise => boutique.value?.devise ?? 'GNF';

  bool get peutAnnuler {
    if (vente.value == null) return false;
    if (vente.value!.statut != VenteStatut.validee) return false;
    // Annulation : opération métier ouverte au super-admin (sans
    // restriction) ou au gestionnaire. Admin pur en lecture seule.
    return UserController.to.canPerformSales;
  }

  Future<void> confirmCancel() async {
    if (!peutAnnuler) return;

    // Le champ du motif vit dans le dialogue, pas ici : un
    // TextEditingController créé dans un controller n'a pas de propriétaire
    // pour le disposer au bon moment.
    final motif = await MotifAnnulationDialog.demander(
      titre: 'Annuler la vente ?',
      message: 'La vente sera marquée comme annulée et l\'effet sur le '
          'solde client sera inversé.\nCette action est tracée.',
      libelleConfirmer: 'Annuler la vente',
    );
    if (motif == null) return;

    final userId = UserController.to.user?.id;
    if (userId == null) return;

    isCanceling.value = true;
    try {
      await _venteRepo.cancel(
        venteId: venteId!,
        userId: userId,
        motif: motif,
      );
      Get.snackbar(
        'Vente annulée',
        'L\'effet sur le solde client a été inversé.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Annulation impossible : $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isCanceling.value = false;
    }
  }
}
