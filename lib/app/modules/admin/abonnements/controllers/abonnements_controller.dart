import 'package:get/get.dart';

import '../../../../data/models/abonnement_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/abonnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';

class AbonnementsController extends GetxController {
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final AbonnementRepository _aboRepo = AbonnementRepository();

  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  /// Tous les paiements, triés par `dateFin` desc. Permet de retrouver
  /// le dernier paiement d'une boutique sans faire de read additionnel
  /// par tuile (`firstWhereOrNull` côté client).
  final RxList<AbonnementModel> _allAbonnements = <AbonnementModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;

  /// Filtre rapide : tout / actives / expirées / sans abonnement.
  final Rx<AbonnementFilter> filter = AbonnementFilter.toutes.obs;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: null));
    _allAbonnements.bindStream(_aboRepo.watchAll());
    debounce(boutiques, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  /// Renvoie le dernier paiement enregistré pour une boutique (le plus
  /// récent par `dateFin`). Lecture mémoire — pas de read Firestore.
  AbonnementModel? latestForBoutique(String boutiqueId) {
    return _allAbonnements.firstWhereOrNull(
      (a) => a.boutiqueId == boutiqueId,
    );
  }

  /// Liste filtrée triée : expirées d'abord (urgent), puis par jours
  /// restants croissants (proches de l'expiration en haut), puis sans
  /// abonnement, puis abonnement loin dans le futur.
  List<BoutiqueModel> get filtered {
    final q = search.value.trim().toLowerCase();
    final now = DateTime.now();
    final base = boutiques.where((b) {
      if (q.isNotEmpty &&
          !b.nom.toLowerCase().contains(q) &&
          !(b.adresse?.toLowerCase().contains(q) ?? false)) {
        return false;
      }
      switch (filter.value) {
        case AbonnementFilter.toutes:
          return true;
        case AbonnementFilter.actives:
          return b.subscriptionEndsAt != null &&
              b.subscriptionEndsAt!.isAfter(now);
        case AbonnementFilter.expirees:
          return b.subscriptionEndsAt != null &&
              !b.subscriptionEndsAt!.isAfter(now);
        case AbonnementFilter.sansAbonnement:
          return b.subscriptionEndsAt == null;
      }
    }).toList();
    base.sort((a, b) {
      // Sans abonnement : tout en bas
      if (a.subscriptionEndsAt == null && b.subscriptionEndsAt == null) {
        return 0;
      }
      if (a.subscriptionEndsAt == null) return 1;
      if (b.subscriptionEndsAt == null) return -1;
      return a.subscriptionEndsAt!.compareTo(b.subscriptionEndsAt!);
    });
    return base;
  }

  int get totalActives {
    final now = DateTime.now();
    return boutiques
        .where((b) =>
            b.subscriptionEndsAt != null &&
            b.subscriptionEndsAt!.isAfter(now))
        .length;
  }

  int get totalExpirees {
    final now = DateTime.now();
    return boutiques
        .where((b) =>
            b.subscriptionEndsAt != null &&
            !b.subscriptionEndsAt!.isAfter(now))
        .length;
  }

  int get totalSansAbonnement =>
      boutiques.where((b) => b.subscriptionEndsAt == null).length;
}

enum AbonnementFilter { toutes, actives, expirees, sansAbonnement }
