import 'package:get/get.dart';

import 'package:flutter/material.dart';

import '../../../../core/services/receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/client_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

enum PeriodeFiltre { aujourdhui, semaine, mois, personnalise, tout }

class VentesController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();
  final ClientRepository _clientRepo = ClientRepository();
  final ProduitRepository _produitRepo = ProduitRepository();

  final RxList<VenteModel> _all = <VenteModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> vendeurs = <UserModel>[].obs;
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxnString filterBoutiqueId = RxnString();
  final RxnString filterVendeurId = RxnString();
  final RxnString filterClientId = RxnString();
  final RxnString filterProduitId = RxnString();
  final Rxn<ModePaiement> filterModePaiement = Rxn<ModePaiement>();
  final RxBool inclureAnnulees = false.obs;
  /// false = toutes, true = uniquement ventes partiellement payées (crédit)
  final RxBool onlyAvecCredit = false.obs;
  final RxString search = ''.obs;
  final Rx<PeriodeFiltre> periode = PeriodeFiltre.tout.obs;
  /// Bornes de la période personnalisée (incluses). Ignorées si
  /// [periode] != [PeriodeFiltre.personnalise].
  final Rxn<DateTime> customDebut = Rxn<DateTime>();
  final Rxn<DateTime> customFin = Rxn<DateTime>();

  bool get isAdmin => UserController.to.isAdmin;
  bool get isVendeur => UserController.to.isVendeur;
  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  /// Désigne quel rôle a accès à la vue : super-admin, admin de boutique
  /// (filtre auto sur sa boutique), ou vendeur (filtre auto sur ses ventes).
  bool get isAnyAdmin => UserController.to.isAnyAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    vendeurs.bindStream(_userRepo.watchScoped(scope: scope));
    clients.bindStream(_clientRepo.watchScoped(scope));
    produits.bindStream(_produitRepo.watchAll(boutiqueId: scope));

    if (isVendeur) {
      // Vendeur : ne voit que ses propres ventes
      final user = UserController.to.user;
      filterVendeurId.value = user?.id;
      filterBoutiqueId.value = user?.boutiqueId;
    } else if (isAdmin) {
      // Admin de boutique : ne voit que les ventes de sa boutique
      filterBoutiqueId.value = UserController.to.boutiqueId;
    }

    _bind();

    // Réagir aux changements de filtre
    everAll(
      [filterBoutiqueId, filterVendeurId, periode, customDebut, customFin],
      (_) => _bind(),
    );
  }

  void _bind() {
    isLoading.value = true;
    DateTime? after;
    final now = DateTime.now();
    switch (periode.value) {
      case PeriodeFiltre.aujourdhui:
        after = DateTime(now.year, now.month, now.day);
        break;
      case PeriodeFiltre.semaine:
        after = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        break;
      case PeriodeFiltre.mois:
        after = DateTime(now.year, now.month, 1);
        break;
      case PeriodeFiltre.personnalise:
        // Borne basse Firestore = customDebut. La borne haute (customFin)
        // est appliquée côté client dans `filtered` pour rester compatible
        // avec le repo existant (qui ne prend que `after`).
        final d = customDebut.value;
        after = d == null ? null : DateTime(d.year, d.month, d.day);
        break;
      case PeriodeFiltre.tout:
        after = null;
        break;
    }
    _all.bindStream(_venteRepo.watchAll(
      boutiqueId: filterBoutiqueId.value,
      vendeurId: filterVendeurId.value,
      after: after,
    ));
    debounce(_all, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  List<VenteModel> get filtered {
    final q = search.value.trim().toLowerCase();
    // Borne haute de la période personnalisée (fin de journée incluse).
    DateTime? avant;
    if (periode.value == PeriodeFiltre.personnalise &&
        customFin.value != null) {
      final f = customFin.value!;
      avant = DateTime(f.year, f.month, f.day, 23, 59, 59, 999);
    }
    return _all.where((v) {
      if (avant != null && v.date.isAfter(avant)) return false;
      if (!inclureAnnulees.value && v.statut == VenteStatut.annulee) {
        return false;
      }
      if (filterModePaiement.value != null &&
          v.modePaiement != filterModePaiement.value) {
        return false;
      }
      if (filterClientId.value != null) {
        if (filterClientId.value == _diversSentinel) {
          // Pseudo-id "client divers" → ventes sans clientId
          if (v.clientId != null) return false;
        } else if (v.clientId != filterClientId.value) {
          return false;
        }
      }
      if (filterProduitId.value != null) {
        // Vente concernée si au moins une ligne pointe sur ce produit.
        final pid = filterProduitId.value!;
        if (!v.articles.any((a) => a.produitId == pid)) return false;
      }
      if (onlyAvecCredit.value) {
        if (v.statut != VenteStatut.validee) return false;
        if (v.resteAPayer <= 0) return false;
      }

      if (q.isEmpty) return true;
      // Recherche : numéro de vente, nom client (libre ou enregistré),
      // nom vendeur.
      final numero = v.numeroAffichage.toLowerCase();
      if (numero.contains(q)) return true;
      final nomLibre = v.clientNomLibre?.toLowerCase() ?? '';
      if (nomLibre.contains(q)) return true;
      final clientName = clientNom(v.clientId).toLowerCase();
      if (clientName.contains(q)) return true;
      final vendeurName = vendeurNom(v.vendeurId).toLowerCase();
      if (vendeurName.contains(q)) return true;
      return false;
    }).toList();
  }

  /// Helper view : nom du produit pour l'affichage dans le sélecteur de
  /// filtre (et si besoin pour les badges).
  String produitNom(String? id) {
    if (id == null || id.isEmpty) return '';
    return produits.firstWhereOrNull((p) => p.id == id)?.nom ?? '';
  }

  /// Sentinel utilisé en valeur de [filterClientId] pour cibler les ventes
  /// "client divers" (clientId == null). Une chaîne arbitraire qui ne peut
  /// pas être un vrai ID Firestore.
  static const String _diversSentinel = '__divers__';
  String get diversSentinel => _diversSentinel;

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String vendeurNom(String id) =>
      vendeurs.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  /// Renvoie le libellé client pour une vente : nom enregistré, nom libre,
  /// ou « Client divers ».
  String clientNomVente(VenteModel v) {
    if (v.clientId != null && v.clientId!.isNotEmpty) {
      final c = clients.firstWhereOrNull((x) => x.id == v.clientId);
      if (c != null) return c.nom;
    }
    if (v.clientNomLibre != null && v.clientNomLibre!.isNotEmpty) {
      return v.clientNomLibre!;
    }
    return 'Client divers';
  }

  /// Helper utilisé dans la recherche.
  String clientNom(String? id) {
    if (id == null || id.isEmpty) return '';
    return clients.firstWhereOrNull((c) => c.id == id)?.nom ?? '';
  }

  String deviseDe(String boutiqueId) =>
      boutiques.firstWhereOrNull((b) => b.id == boutiqueId)?.devise ?? 'GNF';

  // ======== Stats ========
  double get caTotal => filtered
      .where((v) => v.statut == VenteStatut.validee)
      .fold(0.0, (acc, v) => acc + v.total);

  int get nbVentesValidees =>
      filtered.where((v) => v.statut == VenteStatut.validee).length;

  /// Renvoie le client lié à une vente, ou `null` (client divers).
  ClientModel? clientDeVente(VenteModel v) {
    if (v.clientId == null || v.clientId!.isEmpty) return null;
    return clients.firstWhereOrNull((c) => c.id == v.clientId);
  }

  // ======== Réimpression rapide du reçu ========
  Future<void> reimprimerRecu(VenteModel vente) async {
    final boutique =
        boutiques.firstWhereOrNull((b) => b.id == vente.boutiqueId) ??
            await _boutiqueRepo.getById(vente.boutiqueId);
    if (boutique == null) {
      _snackError('Boutique introuvable');
      return;
    }
    final vendeur = vendeurs.firstWhereOrNull((u) => u.id == vente.vendeurId) ??
        await _userRepo.getById(vente.vendeurId);
    final clientLabel = clientNomVente(vente);
    try {
      await ReceiptService.sharePrint(
        vente: vente,
        boutique: boutique,
        vendeur: vendeur,
        clientLabel: clientLabel,
      );
    } catch (e) {
      _snackError('Impression impossible : $e');
    }
  }

  void _snackError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
    );
  }
}
