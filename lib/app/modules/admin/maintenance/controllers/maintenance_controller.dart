import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/maintenance_repository.dart';
import '../widgets/confirm_purge_dialog.dart';

/// Purge ciblée des données d'une boutique. Écran réservé au super-admin.
class MaintenanceController extends GetxController {
  final MaintenanceRepository _repo = MaintenanceRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  /// Boutique ciblée. Volontairement `null` au départ : aucune boutique
  /// pré-sélectionnée sur un écran destructif, pour qu'aucune purge ne
  /// puisse partir sur une cible choisie par défaut.
  final RxnString boutiqueId = RxnString();

  /// Nombre de documents par cible. `null` = pas encore compté.
  final RxMap<PurgeCible, int?> compteurs = <PurgeCible, int?>{}.obs;

  final RxBool isCounting = false.obs;

  /// Cible en cours de purge, `null` si aucune.
  final Rxn<PurgeCible> enCours = Rxn<PurgeCible>();

  /// Progression de la purge en cours (documents supprimés).
  final RxInt progression = 0.obs;

  List<PurgeCible> get cibles => PurgeCible.values;

  BoutiqueModel? get boutique =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId.value);

  @override
  void onInit() {
    super.onInit();
    // Super-admin : scope null, donc toutes les boutiques.
    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: UserController.to.scopeBoutiqueId),
    );
    ever(boutiqueId, (_) => rafraichirCompteurs());
  }

  /// Recompte toutes les cibles pour la boutique sélectionnée.
  Future<void> rafraichirCompteurs() async {
    final bid = boutiqueId.value;
    compteurs.clear();
    if (bid == null || bid.isEmpty) return;
    isCounting.value = true;
    try {
      for (final c in cibles) {
        compteurs[c] = await _repo.compter(c, bid);
      }
    } catch (e) {
      _snackError('Comptage impossible : $e');
    } finally {
      isCounting.value = false;
    }
  }

  /// Demande une double confirmation, puis purge.
  ///
  /// La saisie du nom exact de la boutique est exigée : sur une action
  /// irréversible et sans corbeille, un simple « Confirmer » se clique par
  /// réflexe. Recopier le nom force à vérifier la cible.
  Future<void> confirmerEtPurger(PurgeCible cible) async {
    final b = boutique;
    if (b == null) {
      _snackError('Sélectionnez d\'abord une boutique.');
      return;
    }
    final nb = compteurs[cible] ?? 0;
    if (nb == 0) {
      Get.snackbar(
        'Rien à supprimer',
        '${cible.label} : aucune donnée pour « ${b.nom} ».',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    // Le dialogue est un widget à part : son TextEditingController doit
    // vivre dans un State, pas ici. Le disposer au retour de Get.dialog le
    // détruirait pendant l'animation de fermeture, alors que le TextField
    // se reconstruit encore.
    final ok = await ConfirmPurgeDialog.show(
      boutiqueNom: b.nom,
      cible: cible,
      nbDocuments: nb,
    );
    if (!ok) return;

    enCours.value = cible;
    progression.value = 0;
    try {
      final total = await _repo.purger(
        cible,
        b.id,
        onProgress: (n) => progression.value = n,
      );
      compteurs[cible] = await _repo.compter(cible, b.id);
      Get.snackbar(
        'Purge terminée',
        '$total document(s) supprimé(s) — ${cible.label}.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      _snackError('Purge interrompue : $e');
      // Une purge partielle laisse des données : on recompte pour que
      // l'écran reflète l'état réel plutôt que l'état espéré.
      await rafraichirCompteurs();
    } finally {
      enCours.value = null;
      progression.value = 0;
    }
  }

  void _snackError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      duration: const Duration(seconds: 5),
    );
  }
}
