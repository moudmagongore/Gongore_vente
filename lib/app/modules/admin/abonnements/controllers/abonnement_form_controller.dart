import 'dart:async';

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

  /// Dernier paiement enregistré pour la boutique sélectionnée.
  /// Affiché dans la fiche pour que le super-admin voie immédiatement
  /// les données exactes du dernier abonnement (montant, période, dates,
  /// note) — utile pour vérifier ou renouveler à l'identique.
  final Rxn<AbonnementModel> latestAbonnement = Rxn<AbonnementModel>();
  StreamSubscription<List<AbonnementModel>>? _latestSub;

  /// Drapeau interne : quand on pré-remplit le formulaire avec les valeurs
  /// du dernier paiement, on doit éviter que les listeners `ever(periode)`
  /// / `ever(boutiqueId)` n'écrasent le montant par le tarif standard.
  bool _suppressMontantRefill = false;

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

    // IMPORTANT : enregistrer les `ever` AVANT toute affectation à
    // `boutiqueId` / `periode`. Sinon, la pré-sélection issue de
    // `Get.arguments` se ferait avant que les listeners n'existent et le
    // dernier paiement de la boutique ne serait jamais chargé.
    //
    // Changement de période → on écrase toujours le montant par le tarif
    // configuré pour la nouvelle période (l'utilisateur s'attend à voir
    // le prix se mettre à jour quand il change la période).
    ever(periode, (_) => _refillMontant(force: true));
    // Changement de boutique : recharge le dernier paiement de cette
    // boutique pour pré-remplir le formulaire avec les valeurs exactes.
    ever(boutiqueId, _onBoutiqueChanged);
    ever(params, (_) => _refillMontant(force: false));

    // Pré-sélection si la vue liste a passé une boutique en argument :
    // déclenche `_onBoutiqueChanged` qui chargera le dernier abonnement.
    final arg = Get.arguments;
    if (arg is BoutiqueModel) {
      boutiqueId.value = arg.id;
    }
  }

  /// Appelé à chaque changement de boutique : abonne au flux du dernier
  /// paiement de cette boutique et pré-remplit le formulaire (période,
  /// montant exact, note) avec les valeurs du dernier abonnement trouvé.
  void _onBoutiqueChanged(String? bid) {
    _latestSub?.cancel();
    _latestSub = null;
    if (bid == null || bid.isEmpty) {
      latestAbonnement.value = null;
      _refillMontant(force: false);
      return;
    }
    _latestSub = _aboRepo.watchByBoutique(bid).listen((list) {
      if (list.isEmpty) {
        latestAbonnement.value = null;
        // Pas de précédent paiement : retombe sur le tarif standard.
        _refillMontant(force: false);
        return;
      }
      final latest = list.first; // déjà trié par dateFin desc
      latestAbonnement.value = latest;

      // Pré-remplit période + montant + note avec les valeurs EXACTES.
      // Le drapeau évite que l'écouteur `ever(periode)` n'écrase le
      // montant par le tarif standard juste après notre écriture.
      _suppressMontantRefill = true;
      if (periode.value != latest.periode) {
        periode.value = latest.periode;
      }
      montantCtrl.text = latest.montant.toStringAsFixed(0);
      noteCtrl.text = latest.note ?? '';
      _suppressMontantRefill = false;
    });
  }

  void _refillMontant({required bool force}) {
    if (_suppressMontantRefill) return;
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
    _latestSub?.cancel();
    montantCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }

  String? validateMontant(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Montant requis';
    final n = double.tryParse(t.replaceAll(',', '.'));
    // 0 est autorisé (ex: paiement gratuit / promo / commercial offert).
    // On refuse uniquement un format invalide ou un montant négatif.
    if (n == null || n < 0) return 'Montant invalide';
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
