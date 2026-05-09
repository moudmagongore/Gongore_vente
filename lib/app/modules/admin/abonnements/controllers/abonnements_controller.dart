import 'package:get/get.dart';

import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/boutique_repository.dart';

class AbonnementsController extends GetxController {
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;

  /// Filtre rapide : tout / actives / expirées / sans abonnement.
  final Rx<AbonnementFilter> filter = AbonnementFilter.toutes.obs;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: null));
    debounce(boutiques, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
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
