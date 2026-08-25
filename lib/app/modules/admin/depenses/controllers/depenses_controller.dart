import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/depense_model.dart';
import '../../../../data/models/nature_depense_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/depense_repository.dart';
import '../../../../data/repositories/nature_depense_repository.dart';
import '../../../../data/repositories/user_repository.dart';

enum PeriodeDepense { aujourdhui, semaine, mois, tout }

/// Total dépensé pour une nature sur la période filtrée.
class DepenseParNature {
  final String natureId;
  final String nom;
  final int nb;
  final double total;

  const DepenseParNature({
    required this.natureId,
    required this.nom,
    required this.nb,
    required this.total,
  });
}

class DepensesController extends GetxController {
  final DepenseRepository _repo = DepenseRepository();
  final NatureDepenseRepository _natureRepo = NatureDepenseRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();

  final RxList<DepenseModel> _all = <DepenseModel>[].obs;
  final RxList<NatureDepenseModel> natures = <NatureDepenseModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rx<PeriodeDepense> periode = PeriodeDepense.mois.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterNatureId = RxnString();
  final RxString search = ''.obs;

  final RxBool isSaving = false.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  /// Admin comme gestionnaire peuvent déclarer une dépense. Seul le
  /// paramétrage des natures est réservé à l'admin.
  bool get canDeclare => UserController.to.canDeclareDepense;

  /// Correction / suppression : l'admin de la boutique sur tout, l'auteur
  /// sur ses propres saisies. Aligné sur les rules Firestore.
  bool canEdit(DepenseModel d) {
    if (isSuperAdmin || isAnyAdmin) return true;
    return d.userId == UserController.to.user?.id;
  }

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    if (scope != null) filterBoutiqueId.value = scope;

    natures.bindStream(_natureRepo.watchScoped(scope));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));

    _bind();
    everAll([periode, filterBoutiqueId], (_) => _bind());
  }

  void _bind() {
    isLoading.value = true;
    _all.bindStream(_repo.watchAll(
      boutiqueId: filterBoutiqueId.value,
      after: _afterDate(periode.value),
    ));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  DateTime? _afterDate(PeriodeDepense p) {
    final now = DateTime.now();
    switch (p) {
      case PeriodeDepense.aujourdhui:
        return DateTime(now.year, now.month, now.day);
      case PeriodeDepense.semaine:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case PeriodeDepense.mois:
        return DateTime(now.year, now.month, 1);
      case PeriodeDepense.tout:
        return null;
    }
  }

  // ===== Filtrage côté client =====
  List<DepenseModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final natureFilter = filterNatureId.value;
    return _all.where((d) {
      if (natureFilter != null && d.natureId != natureFilter) return false;
      if (q.isEmpty) return true;
      return d.natureNom.toLowerCase().contains(q) ||
          (d.commentaire?.toLowerCase().contains(q) ?? false) ||
          userNom(d.userId).toLowerCase().contains(q);
    }).toList();
  }

  // ===== Stats =====
  double get totalDepenses => filtered.fold(0.0, (acc, d) => acc + d.montant);
  int get nbDepenses => filtered.length;

  /// Répartition par nature sur la période, de la plus lourde à la plus
  /// légère. Regroupe sur `natureId` mais affiche le libellé dénormalisé
  /// (une nature supprimée reste donc lisible).
  List<DepenseParNature> get parNature {
    final acc = <String, ({String nom, int nb, double total})>{};
    for (final d in filtered) {
      final cur = acc[d.natureId] ?? (nom: d.natureNom, nb: 0, total: 0.0);
      acc[d.natureId] = (
        nom: cur.nom,
        nb: cur.nb + 1,
        total: cur.total + d.montant,
      );
    }
    final list = acc.entries
        .map((e) => DepenseParNature(
              natureId: e.key,
              nom: e.value.nom,
              nb: e.value.nb,
              total: e.value.total,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  // ===== Helpers =====
  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  String boutiqueNom(String? id) {
    if (id == null || id.isEmpty) return '—';
    return boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';
  }

  /// Natures proposables à la saisie pour une boutique : uniquement les
  /// natures actives de CETTE boutique.
  List<NatureDepenseModel> naturesActives(String? boutiqueId) {
    if (boutiqueId == null || boutiqueId.isEmpty) {
      return <NatureDepenseModel>[];
    }
    return natures
        .where((n) => n.active && n.boutiqueId == boutiqueId)
        .toList();
  }

  /// Natures présentes dans la liste courante (pour le filtre) — inclut
  /// celles devenues inactives depuis.
  List<({String id, String nom})> get naturesFiltrables {
    final seen = <String, String>{};
    for (final d in _all) {
      seen.putIfAbsent(d.natureId, () => d.natureNom);
    }
    final list = seen.entries.map((e) => (id: e.key, nom: e.value)).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    return list;
  }

  // ===== Écritures =====

  /// Déclare une dépense. La date est posée ici, au moment de la saisie —
  /// elle n'est jamais choisie par l'utilisateur.
  Future<bool> declarer({
    required NatureDepenseModel nature,
    required double montant,
    String? commentaire,
  }) async {
    final userId = UserController.to.user?.id;
    if (userId == null) {
      _snackError('Session expirée, reconnectez-vous.');
      return false;
    }
    isSaving.value = true;
    try {
      await _repo.create(DepenseModel(
        id: '',
        natureId: nature.id,
        natureNom: nature.nom,
        montant: montant,
        commentaire: commentaire,
        boutiqueId: nature.boutiqueId,
        userId: userId,
        date: DateTime.now(),
      ));
      // Pas de snackbar ici : l'appelant doit d'abord fermer le sheet.
      // `Get.snackbar` pousse sa propre route, et un `Get.back()` déclenché
      // ensuite fermerait le snackbar au lieu du bottom sheet.
      return true;
    } catch (e) {
      _snackError('Enregistrement impossible : $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> corriger({
    required DepenseModel depense,
    required NatureDepenseModel nature,
    required double montant,
    String? commentaire,
  }) async {
    isSaving.value = true;
    try {
      await _repo.update(DepenseModel(
        id: depense.id,
        natureId: nature.id,
        natureNom: nature.nom,
        montant: montant,
        commentaire: commentaire,
        boutiqueId: depense.boutiqueId,
        userId: depense.userId,
        date: depense.date,
        createdAt: depense.createdAt,
      ));
      // Voir [declarer] : le snackbar de succès est laissé à l'appelant,
      // qui ferme le sheet en premier.
      return true;
    } catch (e) {
      _snackError('Modification impossible : $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Snackbar de confirmation, à appeler APRÈS la fermeture du sheet.
  void snackSucces({required bool edition, required String natureNom}) {
    Get.snackbar(
      edition ? 'Dépense modifiée' : 'Dépense enregistrée',
      natureNom,
      snackPosition: SnackPosition.TOP,
    );
  }

  Future<void> confirmDelete(DepenseModel d) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer la dépense ?'),
        content: Text(
          '« ${d.natureNom} » — ${d.montant.toStringAsFixed(0)}\n\n'
          'Cette suppression est définitive.',
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
      await _repo.delete(d.id);
      Get.snackbar('Dépense supprimée', d.natureNom,
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      _snackError('Suppression impossible : $e');
    }
  }

  void _snackError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
    );
  }
}
