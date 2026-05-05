import 'package:get/get.dart';

import '../../../../core/services/reglement_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/reglement_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/client_repository.dart';
import '../../../../data/repositories/reglement_repository.dart';
import '../../../../data/repositories/user_repository.dart';

enum PeriodeReglement { aujourdhui, semaine, mois, tout }

class ReglementsController extends GetxController {
  final ReglementRepository _repo = ReglementRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final ClientRepository _clientRepo = ClientRepository();
  final UserRepository _userRepo = UserRepository();

  final RxList<ReglementModel> _all = <ReglementModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;

  final RxBool isLoading = true.obs;
  final Rx<PeriodeReglement> periode = PeriodeReglement.mois.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterClientId = RxnString();
  final RxnString filterUserId = RxnString();
  final Rxn<ModePaiement> filterMode = Rxn<ModePaiement>();
  final RxString search = ''.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    if (!isSuperAdmin) {
      filterBoutiqueId.value = UserController.to.boutiqueId;
    } else {
      // IMPORTANT : enregistre l'auto-select AVANT bindStream pour ne pas
      // rater la 1re émission du stream (cache Firestore peut émettre
      // immédiatement). Pour super-admin sans boutique pré-sélectionnée :
      // prend la 1re boutique disponible. Modifiable via filtre.
      ever<List<BoutiqueModel>>(boutiques, (list) {
        if (filterBoutiqueId.value == null && list.isNotEmpty) {
          filterBoutiqueId.value = list.first.id;
        }
      });
    }

    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    clients.bindStream(_clientRepo.watchScoped(scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));

    _bind();
    everAll([periode, filterBoutiqueId], (_) => _bind());
  }

  void _bind() {
    isLoading.value = true;
    var scope = filterBoutiqueId.value;
    // Fallback : super-admin sans boutique sélectionnée et boutiques chargées
    // → auto-sélection de la 1re. Évite l'écran vide si l'`ever` n'a pas
    // fait son travail à temps.
    if ((scope == null || scope.isEmpty) &&
        isSuperAdmin &&
        boutiques.isNotEmpty) {
      scope = boutiques.first.id;
      filterBoutiqueId.value = scope;
    }
    if (scope == null || scope.isEmpty) {
      _all.value = [];
      isLoading.value = false;
      return;
    }
    _all.bindStream(
      _repo.watchByBoutique(scope, after: _afterDate(periode.value)),
    );
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  DateTime? _afterDate(PeriodeReglement p) {
    final now = DateTime.now();
    switch (p) {
      case PeriodeReglement.aujourdhui:
        return DateTime(now.year, now.month, now.day);
      case PeriodeReglement.semaine:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case PeriodeReglement.mois:
        return DateTime(now.year, now.month, 1);
      case PeriodeReglement.tout:
        return null;
    }
  }

  // ===== Filtrage côté client =====
  List<ReglementModel> get filtered {
    final q = search.value.trim().toLowerCase();
    return _all.where((r) {
      if (filterClientId.value != null && r.clientId != filterClientId.value) {
        return false;
      }
      if (filterUserId.value != null && r.userId != filterUserId.value) {
        return false;
      }
      if (filterMode.value != null && r.modePaiement != filterMode.value) {
        return false;
      }
      if (q.isEmpty) return true;
      final clientName = clientNom(r.clientId).toLowerCase();
      if (clientName.contains(q)) return true;
      final userName = userNom(r.userId).toLowerCase();
      if (userName.contains(q)) return true;
      return (r.note?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  // ===== Stats =====
  double get totalEncaisse => filtered.fold(0.0, (acc, r) => acc + r.montant);
  int get nbReglements => filtered.length;

  // ===== Helpers =====
  String clientNom(String id) =>
      clients.firstWhereOrNull((c) => c.id == id)?.nom ?? '—';

  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  ClientModel? clientById(String id) =>
      clients.firstWhereOrNull((c) => c.id == id);

  Future<void> deleteReglement(ReglementModel r) async {
    try {
      await _repo.deleteAndRestore(r.id);
      Get.snackbar(
        'Règlement supprimé',
        'Le solde du client a été réajusté.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Suppression impossible : $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  /// Réimprime le reçu d'un règlement existant. Récupère boutique, client
  /// et vendeur via les Rx déjà chargées (avec fallback Firestore).
  Future<void> reimprimerRecu(ReglementModel r) async {
    final client = clientById(r.clientId) ??
        await _clientRepo.getById(r.clientId);
    if (client == null) {
      Get.snackbar(
        'Erreur',
        'Client introuvable.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    final boutique = boutiques.firstWhereOrNull((b) => b.id == r.boutiqueId) ??
        await _boutiqueRepo.getById(r.boutiqueId);
    if (boutique == null) {
      Get.snackbar(
        'Erreur',
        'Boutique introuvable.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    final vendeur = users.firstWhereOrNull((u) => u.id == r.userId) ??
        (r.userId.isEmpty ? null : await _userRepo.getById(r.userId));
    try {
      await ReglementReceiptService.sharePrint(
        reglement: r,
        boutique: boutique,
        client: client,
        vendeur: vendeur,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impression impossible : $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }
}
