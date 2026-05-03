import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';
import '../../../../data/repositories/client_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/vente_repository.dart';
import '../../../../routes/app_routes.dart';

/// Une ligne du bon de vente : produit + quantité + prix figé + remise éventuelle.
class LigneVente {
  final ProduitModel produit;
  int quantite;
  final double prixUnitaire; // figé au moment de l'ajout
  double remise;

  LigneVente({
    required this.produit,
    required this.quantite,
    required this.prixUnitaire,
    this.remise = 0,
  });

  double get sousTotalBrut => prixUnitaire * quantite;
  double get sousTotal => sousTotalBrut - remise;

  VenteArticle toVenteArticle() => VenteArticle(
        produitId: produit.id,
        nom: produit.nom,
        quantite: quantite,
        prixUnitaire: prixUnitaire,
        remise: remise,
      );
}

/// Controller du formulaire « Nouvelle vente » :
/// - Sélection client (existant ou divers avec nom libre)
/// - Ajout d'articles via une modale (qty + remise, prix figé)
/// - Totaux + remise globale + mode paiement + note
/// - Validation avec transaction atomique côté repository
class VenteFormController extends GetxController {
  final ProduitRepository _produitRepo = ProduitRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final CategorieRepository _catRepo = CategorieRepository();
  final ClientRepository _clientRepo = ClientRepository();
  final VenteRepository _venteRepo = VenteRepository();

  // ===== Boutique =====
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxnString currentBoutiqueId = RxnString();

  // ===== Catalogue =====
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;
  final RxList<CategorieModel> categories = <CategorieModel>[].obs;

  // ===== Clients =====
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxnString clientId = RxnString();
  final RxString clientNomLibre = ''.obs;

  // ===== Lignes de la vente =====
  final RxList<LigneVente> lignes = <LigneVente>[].obs;

  // ===== Paiement / total / méta =====
  final RxDouble remiseGlobale = 0.0.obs;
  final Rx<ModePaiement> modePaiement = ModePaiement.especes.obs;
  final RxString note = ''.obs;

  /// Montant effectivement encaissé. Par défaut suit `total`. Si l'utilisateur
  /// l'édite manuellement (ex. paiement partiel), `_montantPayeAuto` passe
  /// à `false` et le champ ne se réajuste plus automatiquement.
  final RxDouble montantPaye = 0.0.obs;
  final RxBool _montantPayeAuto = true.obs;

  /// Avance du client puisée pour couvrir cette vente. 0 par défaut.
  /// Editable par l'utilisateur (clic sur « Utiliser l'avance » ou saisie
  /// manuelle). Plafonné à min(total, |solde négatif| du client).
  final RxDouble avanceUtilisee = 0.0.obs;

  // ===== États =====
  final RxBool isSaving = false.obs;
  final RxBool isLoadingProduits = true.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAdmin => UserController.to.isAdmin;
  bool get canPickBoutique => isSuperAdmin;

  String get devise =>
      boutiques
          .firstWhereOrNull((b) => b.id == currentBoutiqueId.value)
          ?.devise ??
      'GNF';

  String get boutiqueNomCourante =>
      boutiques.firstWhereOrNull((b) => b.id == currentBoutiqueId.value)?.nom ??
      '';

  ClientModel? get clientSelectionne =>
      clientId.value == null
          ? null
          : clients.firstWhereOrNull((c) => c.id == clientId.value);

  /// Libellé client à afficher dans la barre du haut.
  String get clientLabel {
    final c = clientSelectionne;
    if (c != null) return c.nom;
    if (clientNomLibre.value.isNotEmpty) return clientNomLibre.value;
    return 'Client divers';
  }

  bool get isClientDivers => clientId.value == null;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: scope, actives: true),
    );
    categories.bindStream(_catRepo.watchAll(boutiqueId: scope));
    clients.bindStream(_clientRepo.watchScoped(scope));

    // Listener AVANT toute affectation à currentBoutiqueId
    ever(currentBoutiqueId, (String? id) {
      if (id == null || id.isEmpty) return;
      _resetVente();
      isLoadingProduits.value = true;
      produits.bindStream(
        _produitRepo.watchAll(boutiqueId: id, onlyActive: true),
      );
      debounce(produits, (_) => isLoadingProduits.value = false,
          time: const Duration(milliseconds: 200));
    });

    final user = UserController.to.user;
    if ((user?.isVendeur ?? false) || (user?.isAdmin ?? false)) {
      // Vendeur OU admin : verrouillé sur sa boutique
      final bId = user?.boutiqueId;
      if (bId != null && bId.isNotEmpty) {
        currentBoutiqueId.value = bId;
      }
    } else {
      // Super-admin : sélectionne la 1ère boutique disponible
      ever<List<BoutiqueModel>>(boutiques, (list) {
        if (currentBoutiqueId.value == null && list.isNotEmpty) {
          currentBoutiqueId.value = list.first.id;
        }
      });
    }

    // Synchronise montantPaye avec total tant que l'utilisateur ne l'a pas édité.
    ever(lignes, (_) => _autoSyncMontantPaye());
    ever(remiseGlobale, (_) => _autoSyncMontantPaye());

    // Pré-sélection client si on arrive depuis la fiche client
    final arg = Get.arguments;
    if (arg is ClientModel) {
      // On attend que le stream clients ait peuplé la liste pour faire la
      // sélection (l'écran affiche le client sélectionné via firstWhereOrNull)
      clientId.value = arg.id;
    }
  }

  void _resetVente() {
    lignes.clear();
    clientId.value = null;
    clientNomLibre.value = '';
    remiseGlobale.value = 0;
    modePaiement.value = ModePaiement.especes;
    note.value = '';
    montantPaye.value = 0;
    avanceUtilisee.value = 0;
    _montantPayeAuto.value = true;
  }

  /// À appeler à chaque changement susceptible d'altérer le total.
  /// Si l'utilisateur n'a pas édité le montant payé, il suit le total
  /// (paiement intégral par défaut, en tenant compte de l'avance).
  /// Re-clamp aussi l'avance utilisée si elle dépasse le nouveau plafond.
  void _autoSyncMontantPaye() {
    // L'avance ne peut pas excéder le total (on ne peut pas surutiliser).
    final maxApp = avanceMaxApplicable;
    if (avanceUtilisee.value > maxApp) {
      avanceUtilisee.value = maxApp;
    }
    if (_montantPayeAuto.value) {
      montantPaye.value = total - avanceUtilisee.value;
    }
  }

  /// Définit manuellement le montant payé (paiement partiel ou trop-perçu).
  /// Désactive la synchro auto avec le total.
  void setMontantPaye(double value) {
    _montantPayeAuto.value = false;
    montantPaye.value = value < 0 ? 0 : value;
  }

  /// Repasse en mode "intégralement payé" (montant payé = total).
  void resetMontantPayeAuto() {
    _montantPayeAuto.value = true;
    montantPaye.value = total;
  }

  /// Reste à payer après cette vente (positif = crédit, négatif = trop-perçu).
  double get resteAPayer => total - montantPaye.value - avanceUtilisee.value;

  /// Avance disponible sur le compte du client sélectionné (= -solde si
  /// solde < 0, sinon 0). Pour client divers, retourne 0.
  double get avanceDisponible {
    final c = clientSelectionne;
    if (c == null) return 0;
    return c.solde < 0 ? -c.solde : 0;
  }

  /// Avance maximum applicable à cette vente (bornée par le total).
  double get avanceMaxApplicable {
    final dispo = avanceDisponible;
    return dispo > total ? total : dispo;
  }

  /// Applique le maximum d'avance possible et ajuste montantPaye pour que
  /// la vente soit intégralement payée (montantPaye + avance = total).
  /// Désactive l'auto-sync de montantPaye.
  void appliquerAvanceMax() {
    final maxApp = avanceMaxApplicable;
    avanceUtilisee.value = maxApp;
    _montantPayeAuto.value = false;
    montantPaye.value = total - maxApp;
  }

  /// Saisie manuelle d'avance utilisée (clamp 0..avanceMaxApplicable).
  void setAvanceUtilisee(double value) {
    if (value < 0) value = 0;
    final maxApp = avanceMaxApplicable;
    if (value > maxApp) value = maxApp;
    avanceUtilisee.value = value;
    // Si montantPaye était en mode auto, on resync (montantPaye = reste à
    // couvrir après avance). Sinon on laisse l'utilisateur gérer.
    if (_montantPayeAuto.value) {
      montantPaye.value = total - value;
    }
  }

  /// Retire l'avance et repasse en paiement intégral cash.
  void retirerAvance() {
    avanceUtilisee.value = 0;
    _montantPayeAuto.value = true;
    montantPaye.value = total;
  }

  // ===== Client =====
  void selectClient(String? id) {
    clientId.value = id;
    if (id != null) clientNomLibre.value = '';
    // Reset avance : nouvel utilisateur potentiellement avec un solde différent.
    avanceUtilisee.value = 0;
    _autoSyncMontantPaye();
  }

  void setClientNomLibre(String nom) {
    clientNomLibre.value = nom.trim();
    clientId.value = null;
    avanceUtilisee.value = 0;
    _autoSyncMontantPaye();
  }

  void resetClient() {
    clientId.value = null;
    clientNomLibre.value = '';
    avanceUtilisee.value = 0;
    _autoSyncMontantPaye();
  }

  // ===== Lignes =====
  /// Ajoute une nouvelle ligne avec quantité et remise. Le prix unitaire
  /// est figé sur le prix actuel du produit.
  bool addLigne({
    required ProduitModel produit,
    required int quantite,
    double remise = 0,
  }) {
    if (quantite <= 0) {
      _snackError('Quantité invalide');
      return false;
    }
    // Pas de doublon : si le produit est déjà dans le bon, rediriger
    // l'utilisateur vers la ligne existante (modifier qté + remise dessus).
    final dejaPresent =
        lignes.any((l) => l.produit.id == produit.id);
    if (dejaPresent) {
      _snackError(
        '${produit.nom} est déjà dans cette vente. '
        'Modifiez la quantité ou la remise sur la ligne existante.',
      );
      return false;
    }
    final maxRemise = produit.prixVente * quantite;
    final remiseClamp = remise.clamp(0, maxRemise).toDouble();
    lignes.add(LigneVente(
      produit: produit,
      quantite: quantite,
      prixUnitaire: produit.prixVente, // figé
      remise: remiseClamp,
    ));
    return true;
  }

  void incrementLigne(int index) {
    lignes[index].quantite++;
    lignes.refresh();
  }

  void decrementLigne(int index) {
    final l = lignes[index];
    if (l.quantite <= 1) {
      lignes.removeAt(index);
    } else {
      l.quantite--;
      lignes.refresh();
    }
  }

  void setRemiseLigne(int index, double remise) {
    final l = lignes[index];
    final max = l.sousTotalBrut;
    l.remise = remise < 0 ? 0 : (remise > max ? max : remise);
    lignes.refresh();
  }

  void setRemiseLignePourcent(int index, double pct) {
    final p = pct.clamp(0, 100).toDouble();
    setRemiseLigne(index, lignes[index].sousTotalBrut * p / 100);
  }

  void removeLigne(int index) {
    lignes.removeAt(index);
  }

  void clearLignes() {
    lignes.clear();
    remiseGlobale.value = 0;
  }

  // ===== Totaux =====
  double get sousTotal => lignes.fold(0.0, (acc, l) => acc + l.sousTotal);

  double get total {
    final t = sousTotal - remiseGlobale.value;
    return t < 0 ? 0 : t;
  }

  int get nbArticles => lignes.fold(0, (acc, l) => acc + l.quantite);

  // ===== Validation =====
  Future<void> validerVente() async {
    if (lignes.isEmpty) {
      _snackError('Ajoutez au moins un article');
      return;
    }
    if (currentBoutiqueId.value == null) {
      _snackError('Aucune boutique sélectionnée');
      return;
    }
    final userId = UserController.to.user?.id;
    if (userId == null) {
      _snackError('Session expirée');
      return;
    }

    // Bloque le crédit sur un client non identifié — pas de solde à mettre à jour.
    if (resteAPayer > 0 && clientId.value == null) {
      _snackError(
        'Crédit impossible sur un client divers. Sélectionnez un client '
        'enregistré ou complétez le paiement.',
      );
      return;
    }

    isSaving.value = true;
    try {
      final vente = VenteModel(
        id: '',
        boutiqueId: currentBoutiqueId.value!,
        vendeurId: userId,
        clientId: clientId.value,
        clientNomLibre: clientId.value == null && clientNomLibre.value.isNotEmpty
            ? clientNomLibre.value
            : null,
        articles: lignes.map((l) => l.toVenteArticle()).toList(),
        sousTotal: sousTotal,
        remise: remiseGlobale.value,
        total: total,
        montantPaye: montantPaye.value,
        avanceUtilisee: avanceUtilisee.value,
        modePaiement: modePaiement.value,
        date: DateTime.now(),
        note: note.value.isEmpty ? null : note.value,
      );

      final venteId = await _venteRepo.create(vente);

      // Reset
      _resetVente();

      Get.back(); // ferme le formulaire

      Get.snackbar(
        'Vente validée',
        'Total : ${vente.total.toStringAsFixed(0)} $devise',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 200));
      Get.toNamed(AppRoutes.venteDetail, arguments: venteId);
    } catch (e) {
      _snackError('Erreur de validation : $e');
    } finally {
      isSaving.value = false;
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
