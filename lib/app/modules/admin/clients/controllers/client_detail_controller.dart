import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/reglement_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/reglement_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/client_repository.dart';
import '../../../../data/repositories/reglement_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

/// Charge et expose les données d'une fiche client : infos, ventes,
/// règlements, et statistiques agrégées.
class ClientDetailController extends GetxController {
  final ClientRepository _clientRepo = ClientRepository();
  final VenteRepository _venteRepo = VenteRepository();
  final ReglementRepository _reglementRepo = ReglementRepository();

  final Rxn<ClientModel> client = Rxn<ClientModel>();
  final RxList<VenteModel> ventes = <VenteModel>[].obs;
  final RxList<ReglementModel> reglements = <ReglementModel>[].obs;
  final RxBool isLoading = true.obs;

  /// Le client passé en argument (chargé depuis la liste). On l'utilise
  /// d'abord en cache, puis on bind un stream live depuis Firestore pour
  /// avoir le solde à jour après une vente / un règlement.
  String? _clientId;
  String get clientId => _clientId ?? '';

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is ClientModel) {
      _clientId = arg.id;
      client.value = arg; // cache initial
    } else if (arg is String) {
      _clientId = arg;
    } else {
      isLoading.value = false;
      return;
    }

    if (_clientId == null || _clientId!.isEmpty) {
      isLoading.value = false;
      return;
    }

    // Stream live du client → le solde se met à jour automatiquement après
    // une vente avec avance, un règlement, ou toute autre écriture serveur.
    client.bindStream(_clientRepo.watchById(_clientId!));

    // Streams ventes & règlements scopés à ce client
    ventes.bindStream(
      _venteRepo.watchAll(
        boutiqueId: client.value?.boutiqueId,
        // Filtre par client côté serveur impossible en même temps que ordering ;
        // on filtre côté client après réception.
      ).map((all) => all.where((v) => v.clientId == _clientId).toList()),
    );

    final clientBoutiqueId = client.value?.boutiqueId ?? '';
    reglements.bindStream(_reglementRepo.watchByClient(
      _clientId!,
      boutiqueId: clientBoutiqueId,
    ));
    debounce(reglements, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  // ===== Stats =====
  List<VenteModel> get _ventesValidees =>
      ventes.where((v) => v.statut == VenteStatut.validee).toList();

  int get nbVentes => _ventesValidees.length;

  double get totalAchete =>
      _ventesValidees.fold(0.0, (acc, v) => acc + v.total);

  /// Total déjà encaissé (ventes + règlements standalone).
  double get totalEncaisse {
    double sum = 0;
    for (final v in _ventesValidees) {
      sum += v.montantPaye;
    }
    for (final r in reglements) {
      sum += r.montant;
    }
    return sum;
  }

  DateTime? get derniereVisite {
    if (_ventesValidees.isEmpty && reglements.isEmpty) return null;
    DateTime? max;
    for (final v in _ventesValidees) {
      if (max == null || v.date.isAfter(max)) max = v.date;
    }
    for (final r in reglements) {
      if (max == null || r.date.isAfter(max)) max = r.date;
    }
    return max;
  }

  bool get isAdminOrSuper => UserController.to.isAnyAdmin;

  /// Réimprime le reçu d'un règlement existant (depuis l'onglet Règlements
  /// de la fiche client).
  Future<void> reimprimerRecu(ReglementModel r) async {
    final c = client.value;
    if (c == null) return;
    final boutique = await BoutiqueRepository().getById(r.boutiqueId);
    if (boutique == null) {
      Get.snackbar(
        'Erreur',
        'Boutique introuvable.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final vendeur = r.userId.isEmpty
        ? null
        : await UserRepository().getById(r.userId);
    try {
      await ReglementReceiptService.sharePrint(
        reglement: r,
        boutique: boutique,
        client: c,
        vendeur: vendeur,
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
  Future<void> confirmDeleteReglement(ReglementModel r) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer ce règlement ?'),
        content: const Text(
          'Le montant sera ré-ajouté au solde du client. Action réservée '
          'aux corrections d\'erreur de saisie.',
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
