import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../data/models/mouvement_caisse_model.dart';
import '../../../../data/repositories/caisse_repository.dart';
import '../../../../routes/app_routes.dart';

enum PeriodeReleve { aujourdhui, semaine, mois, tout }

/// Relevé d'une caisse sur une période (RG-29).
///
/// La caisse est passée en argument de route. Le relevé est **toujours
/// mono-caisse** : la règle de lecture des mouvements contrôle l'accès du
/// gestionnaire par un `get()` sur la caisse, et une requête multi-caisses
/// ferait sauter le quota d'accès documentaires.
class ReleveCaisseController extends GetxController {
  final CaisseRepository _repo = CaisseRepository();

  final Rxn<CaisseModel> caisse = Rxn<CaisseModel>();
  final RxList<MouvementCaisseModel> _all = <MouvementCaisseModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rx<PeriodeReleve> periode = PeriodeReleve.mois.obs;
  final Rxn<TypeMouvementCaisse> filterType = Rxn<TypeMouvementCaisse>();

  /// Solde juste avant le premier mouvement de la période.
  final RxDouble soldeDebut = 0.0.obs;

  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is CaisseModel) {
      caisse.value = arg;
      // Le solde affiché doit suivre les mouvements qu'on enregistre depuis
      // cet écran : on reste branché sur le document.
      caisse.bindStream(_repo.watchOne(arg.id));
    }
    _bind();
    ever(periode, (_) => _bind());
  }

  void _bind() {
    final c = caisse.value;
    if (c == null) return;
    isLoading.value = true;
    _all.bindStream(_repo.watchMouvements(
      boutiqueId: c.boutiqueId,
      caisseId: c.id,
      after: _debut(periode.value),
    ));
    debounce(_all, (_) => _apresChargement(),
        time: const Duration(milliseconds: 200));
  }

  Future<void> _apresChargement() async {
    await _calculerSoldeDebut();
    isLoading.value = false;
  }

  /// Deux chemins possibles, selon que la période contient des mouvements :
  ///
  /// - elle en contient : le solde de départ se déduit du plus ancien,
  ///   `soldeApres - montantSigne`. Aucune lecture supplémentaire.
  /// - elle est vide : il faut aller chercher le dernier mouvement
  ///   antérieur. Sans lui, on ne saurait pas distinguer une caisse à zéro
  ///   d'une caisse pleine mais inactive sur la période.
  Future<void> _calculerSoldeDebut() async {
    final c = caisse.value;
    if (c == null) return;
    final debut = _debut(periode.value);

    if (_all.isNotEmpty) {
      // Le stream trie du plus récent au plus ancien.
      final premier = _all.last;
      soldeDebut.value = premier.soldeApres - premier.montantSigne;
      return;
    }
    if (debut == null) {
      soldeDebut.value = 0;
      return;
    }
    final precedent = await _repo.dernierMouvementAvant(
      boutiqueId: c.boutiqueId,
      caisseId: c.id,
      avant: debut,
    );
    soldeDebut.value = precedent?.soldeApres ?? 0;
  }

  DateTime? _debut(PeriodeReleve p) {
    final now = DateTime.now();
    switch (p) {
      case PeriodeReleve.aujourdhui:
        return DateTime(now.year, now.month, now.day);
      case PeriodeReleve.semaine:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case PeriodeReleve.mois:
        return DateTime(now.year, now.month, 1);
      case PeriodeReleve.tout:
        return null;
    }
  }

  String get libellePeriode {
    switch (periode.value) {
      case PeriodeReleve.aujourdhui:
        return 'Aujourd\'hui';
      case PeriodeReleve.semaine:
        return 'Cette semaine';
      case PeriodeReleve.mois:
        return 'Ce mois';
      case PeriodeReleve.tout:
        return 'Tout l\'historique';
    }
  }

  /// Mouvements affichés, du plus récent au plus ancien.
  List<MouvementCaisseModel> get filtered {
    final type = filterType.value;
    if (type == null) return _all.toList();
    return _all.where((m) => m.type == type).toList();
  }

  /// Types réellement présents, pour ne proposer que des filtres utiles.
  List<TypeMouvementCaisse> get typesPresents {
    final seen = <TypeMouvementCaisse>{};
    for (final m in _all) {
      seen.add(m.type);
    }
    final list = seen.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  double get totalEntrees => filtered
      .where((m) => m.sens == SensMouvement.entree)
      .fold<double>(0, (acc, m) => acc + m.montant);

  double get totalSorties => filtered
      .where((m) => m.sens == SensMouvement.sortie)
      .fold<double>(0, (acc, m) => acc + m.montant);

  /// Solde à la fin de la période.
  ///
  /// Calculé comme `début + entrées − sorties` **sur la liste non
  /// filtrée** : avec un filtre par type, l'égalité du relevé n'aurait
  /// aucun sens.
  double get soldeFin {
    final entrees = _all
        .where((m) => m.sens == SensMouvement.entree)
        .fold<double>(0, (acc, m) => acc + m.montant);
    final sorties = _all
        .where((m) => m.sens == SensMouvement.sortie)
        .fold<double>(0, (acc, m) => acc + m.montant);
    return soldeDebut.value + entrees - sorties;
  }

  bool get estFiltre => filterType.value != null;

  /// Un mouvement issu d'une opération s'annule en annulant l'opération,
  /// pas depuis le relevé : sinon stock, soldes client et marges
  /// resteraient inchangés.
  bool peutAnnuler(MouvementCaisseModel m) {
    if (m.type == TypeMouvementCaisse.annulation) return false;
    if (m.type == TypeMouvementCaisse.ouverture) return false;
    if (m.sourceId != null && m.sourceId!.isNotEmpty) return false;
    // Apport, retrait, correction : admin seul (RG-27).
    if (m.type.reserveAdmin) return isAnyAdmin;
    // Transfert : l'admin toujours ; le gestionnaire si les DEUX caisses
    // lui sont accessibles au moment de l'annulation (RG-24). Le relevé ne
    // montrant qu'une caisse, on délègue au repository, qui lira l'autre —
    // et les règles Firestore refuseront l'écriture le cas échéant.
    return true;
  }

  /// Ouvre l'opération d'origine d'un mouvement (RG-29).
  void ouvrirSource(MouvementCaisseModel m) {
    final id = m.sourceId;
    if (id == null || id.isEmpty) return;
    switch (m.sourceType) {
      case 'ventes':
        Get.toNamed(AppRoutes.venteDetail, arguments: id);
        break;
      case 'approvisionnements':
        Get.toNamed(AppRoutes.approDetail, arguments: id);
        break;
      default:
        // Dépenses et règlements n'ont pas d'écran de détail dédié : leur
        // liste est le seul point d'entrée.
        Get.snackbar(
          m.type.label,
          'Cette opération se consulte depuis sa propre liste.',
          snackPosition: SnackPosition.TOP,
        );
    }
  }

  Future<void> confirmerAnnulation(MouvementCaisseModel m) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Annuler ce ${m.type.label.toLowerCase()} ?'),
        content: Text(
          '${m.sens.label} de ${Fmt.money(m.montant, currency: 'GNF')} '
          'sur ${m.caisseNom}.\n\n'
          '${m.transfertId != null ? 'Les deux caisses du transfert seront remises à leur état antérieur.\n\n' : ''}'
          'Un mouvement inverse sera enregistré : rien n\'est effacé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Fermer'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Get.back(result: true),
            child: const Text('Annuler le mouvement'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final user = UserController.to.user;
    try {
      await _repo.annulerMouvement(
        m,
        userId: user?.id ?? '',
        userNom: user?.nom ?? '',
      );
      Get.snackbar('Mouvement annulé', 'Le solde est revenu à son état.',
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar(
        'Annulation impossible',
        '$e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  String money(double v) => Fmt.money(v, currency: 'GNF');
}
