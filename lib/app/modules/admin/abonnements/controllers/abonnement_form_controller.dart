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

  /// Liste complète des paiements de la boutique sélectionnée, du plus
  /// récent au plus ancien. Sert à afficher l'historique et à permettre
  /// l'édition / suppression individuelle de chaque paiement.
  final RxList<AbonnementModel> historyAbonnements =
      <AbonnementModel>[].obs;
  StreamSubscription<List<AbonnementModel>>? _historySub;

  /// Raccourci : dernier paiement (premier de la liste triée desc).
  /// Affiché dans la fiche pour que le super-admin voie immédiatement
  /// les données exactes du dernier abonnement.
  AbonnementModel? get latestAbonnement =>
      historyAbonnements.isEmpty ? null : historyAbonnements.first;

  /// Quand non-null, le formulaire est en mode ÉDITION d'un paiement
  /// existant (au lieu d'en créer un nouveau). Le `save()` appelle
  /// `update` au lieu de `create`, la boutique est verrouillée, et un
  /// bouton "Supprimer" apparaît dans l'UI.
  final Rxn<AbonnementModel> editing = Rxn<AbonnementModel>();
  bool get isEditing => editing.value != null;

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

  /// Appelé à chaque changement de boutique : abonne au flux des paiements
  /// de cette boutique. Tant qu'on n'est PAS en mode édition, pré-remplit
  /// aussi le formulaire avec les valeurs exactes du dernier paiement
  /// (période, montant, note). En mode édition, le formulaire affiche les
  /// valeurs de `editing` et ne doit pas être écrasé par le dernier
  /// paiement.
  void _onBoutiqueChanged(String? bid) {
    _historySub?.cancel();
    _historySub = null;
    if (bid == null || bid.isEmpty) {
      historyAbonnements.clear();
      _refillMontant(force: false);
      return;
    }
    _historySub = _aboRepo.watchByBoutique(bid).listen((list) {
      historyAbonnements.assignAll(list);

      // En mode édition, on ne touche pas au formulaire — les champs
      // reflètent le paiement en cours d'édition.
      if (isEditing) return;

      if (list.isEmpty) {
        // Pas de précédent paiement : retombe sur le tarif standard.
        _refillMontant(force: false);
        return;
      }
      final latest = list.first; // déjà trié par dateFin desc

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
    _historySub?.cancel();
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

  /// Bascule le formulaire en mode ÉDITION pour le paiement passé.
  /// Charge ses valeurs exactes dans les champs et verrouille la boutique.
  void startEdit(AbonnementModel abo) {
    editing.value = abo;
    _suppressMontantRefill = true;
    boutiqueId.value = abo.boutiqueId;
    if (periode.value != abo.periode) {
      periode.value = abo.periode;
    }
    montantCtrl.text = abo.montant.toStringAsFixed(0);
    noteCtrl.text = abo.note ?? '';
    _suppressMontantRefill = false;
  }

  /// Quitte le mode édition et restaure le pré-remplissage à partir du
  /// dernier paiement de la boutique (comportement de création).
  void cancelEdit() {
    editing.value = null;
    // Force le re-pré-remplissage depuis le dernier paiement de la boutique
    // (qui peut être différent de celui qu'on éditait).
    final latest = latestAbonnement;
    if (latest != null) {
      _suppressMontantRefill = true;
      if (periode.value != latest.periode) {
        periode.value = latest.periode;
      }
      montantCtrl.text = latest.montant.toStringAsFixed(0);
      noteCtrl.text = latest.note ?? '';
      _suppressMontantRefill = false;
    } else {
      noteCtrl.text = '';
      _refillMontant(force: false);
    }
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
    final note =
        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();

    isSaving.value = true;
    try {
      final editingAbo = editing.value;
      if (editingAbo != null) {
        // MODE ÉDITION : update + recompute boutique.subscriptionEndsAt
        await _aboRepo.update(
          id: editingAbo.id,
          periode: periode.value,
          montant: montant,
          devise: devise,
          note: note,
        );
        Get.back();
        Get.snackbar(
          'Paiement modifié',
          '${selectedBoutique?.nom ?? 'Boutique'} — ${periode.value.label}',
          snackPosition: SnackPosition.TOP,
        );
        return;
      }

      // MODE CRÉATION : create + extension de l'abonnement boutique
      final user = UserController.to.user;
      if (user == null) throw StateError('Utilisateur non connecté');
      await _aboRepo.create(
        boutiqueId: bid,
        periode: periode.value,
        montant: montant,
        devise: devise,
        enregistrePar: user.id,
        note: note,
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

  /// Supprime le paiement passé après confirmation. Recalcule
  /// `boutique.subscriptionEndsAt` dans la même transaction. Si le
  /// paiement supprimé était celui en cours d'édition, on quitte le
  /// mode édition pour repasser en création.
  Future<void> deleteAbonnement(AbonnementModel abo) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer ce paiement ?'),
        content: Text(
          'Le paiement de ${abo.montant.toStringAsFixed(0)} ${abo.devise} '
          '(${abo.periode.label}) sera supprimé. La date de fin '
          'd\'abonnement de la boutique sera recalculée automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Get.back(result: true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _aboRepo.delete(abo.id);
      if (editing.value?.id == abo.id) {
        cancelEdit();
      }
      Get.snackbar(
        'Paiement supprimé',
        'Date de fin recalculée pour la boutique.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _snackError('Erreur : $e');
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
