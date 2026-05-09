import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/abonnement_model.dart';
import '../../../../data/models/abonnement_params_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/abonnement_params_repository.dart';
import '../../../../data/repositories/abonnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';

class AbonnementFormController extends GetxController {
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final AbonnementRepository _aboRepo = AbonnementRepository();
  final AbonnementParamsRepository _paramsRepo =
      AbonnementParamsRepository();

  final formKey = GlobalKey<FormState>();
  final montantCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxnString boutiqueId = RxnString();
  final Rx<AbonnementPeriode> periode = AbonnementPeriode.mois.obs;
  final Rx<AbonnementParamsModel> params =
      const AbonnementParamsModel().obs;
  final RxBool isSaving = false.obs;

  /// Périodes ordonnées telles qu'affichées dans le dropdown.
  final List<AbonnementPeriode> periodes = AbonnementPeriode.values;

  BoutiqueModel? get selectedBoutique =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId.value);

  String get devise => selectedBoutique?.devise ?? 'GNF';

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: null));
    _paramsRepo.watch().listen(params.call);

    // Pré-sélection si la vue liste a passé une boutique en argument.
    final arg = Get.arguments;
    if (arg is BoutiqueModel) {
      boutiqueId.value = arg.id;
    }

    // Changement de période → on écrase toujours le montant par le tarif
    // configuré pour la nouvelle période (l'utilisateur s'attend à voir
    // le prix se mettre à jour quand il change la période).
    ever(periode, (_) => _refillMontant(force: true));
    // Changement de boutique / chargement initial des params → on remplit
    // seulement si le champ est vide (éviter d'écraser une valeur saisie).
    ever(boutiqueId, (_) => _refillMontant(force: false));
    ever(params, (_) => _refillMontant(force: false));
  }

  void _refillMontant({required bool force}) {
    final tarif = params.value.tarifPour(periode.value, devise);
    if (tarif <= 0) {
      // Pas de tarif configuré pour cette période/devise : on laisse le
      // champ tel quel (l'utilisateur saisira manuellement).
      return;
    }
    if (force || montantCtrl.text.trim().isEmpty) {
      montantCtrl.text = tarif.toStringAsFixed(0);
    }
  }

  @override
  void onClose() {
    montantCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }

  String? validateMontant(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Montant requis';
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Montant invalide';
    return null;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final bid = boutiqueId.value;
    if (bid == null || bid.isEmpty) {
      _snackError('Sélectionnez une boutique');
      return;
    }
    final montant =
        double.parse(montantCtrl.text.trim().replaceAll(',', '.'));
    isSaving.value = true;
    try {
      final user = UserController.to.user;
      if (user == null) throw StateError('Utilisateur non connecté');
      await _aboRepo.create(
        boutiqueId: bid,
        periode: periode.value,
        montant: montant,
        devise: devise,
        enregistrePar: user.id,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      Get.back();
      Get.snackbar(
        'Paiement enregistré',
        '${selectedBoutique?.nom ?? 'Boutique'} — ${periode.value.label}',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _snackError('Erreur : $e');
    } finally {
      isSaving.value = false;
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
