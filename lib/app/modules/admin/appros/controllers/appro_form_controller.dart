import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/vente_model.dart' show ModePaiement;
import '../../../../data/repositories/approvisionnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../routes/app_routes.dart';

/// Une ligne d'appro en cours d'édition : produit + qté reçue + PA
/// unitaire saisi par le réceptionniste.
class LigneAppro {
  final ProduitModel produit;
  int quantite;
  double prixAchatUnitaire;

  /// Variante reçue (uniquement quand `produit.hasVariantes`).
  final String? varianteId;
  final String? varianteLibelle;

  LigneAppro({
    required this.produit,
    required this.quantite,
    required this.prixAchatUnitaire,
    this.varianteId,
    this.varianteLibelle,
  });

  double get sousTotal => prixAchatUnitaire * quantite;

  /// Libellé combiné "Veste — 40" si variante, sinon "Veste".
  String get nomComplet =>
      varianteLibelle != null && varianteLibelle!.isNotEmpty
          ? '${produit.nom} — $varianteLibelle'
          : produit.nom;

  ApproArticle toApproArticle() => ApproArticle(
        produitId: produit.id,
        nom: produit.nom,
        varianteId: varianteId,
        varianteLibelle: varianteLibelle,
        quantite: quantite,
        prixAchatUnitaire: prixAchatUnitaire,
      );
}

/// Formulaire « Nouvel approvisionnement » :
/// - Sélection fournisseur (avec affichage du solde / avance)
/// - Lignes : produit + qté reçue + PA unitaire (modale qty + PA)
/// - Totaux + remise globale + mode paiement + montant payé + avance
/// - Validation atomique avec recalcul CMUP côté repository
class ApproFormController extends GetxController {
  final ApprovisionnementRepository _approRepo =
      ApprovisionnementRepository();
  final ProduitRepository _produitRepo = ProduitRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final FournisseurRepository _fournRepo = FournisseurRepository();

  // ===== Boutique =====
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxnString currentBoutiqueId = RxnString();

  // ===== Catalogue =====
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;

  // ===== Fournisseurs =====
  final RxList<FournisseurModel> fournisseurs = <FournisseurModel>[].obs;
  final RxnString fournisseurId = RxnString();

  // ===== Lignes =====
  final RxList<LigneAppro> lignes = <LigneAppro>[].obs;

  // ===== Paiement =====
  final RxDouble remiseGlobale = 0.0.obs;
  final Rx<ModePaiement> modePaiement = ModePaiement.especes.obs;
  final RxString note = ''.obs;

  /// Montant versé au fournisseur au comptant. Par défaut suit le total.
  /// Si édité manuellement, l'auto-sync se désactive.
  final RxDouble montantPaye = 0.0.obs;
  final RxBool _montantPayeAuto = true.obs;

  /// Avance fournisseur consommée (puise sur solde négatif fournisseur).
  final RxDouble avanceUtilisee = 0.0.obs;

  // ===== États =====
  final RxBool isSaving = false.obs;
  final RxBool isLoadingProduits = true.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get canPickBoutique => isSuperAdmin;

  String get devise =>
      boutiques
          .firstWhereOrNull((b) => b.id == currentBoutiqueId.value)
          ?.devise ??
      'GNF';

  String get boutiqueNomCourante =>
      boutiques.firstWhereOrNull((b) => b.id == currentBoutiqueId.value)?.nom ??
      '';

  FournisseurModel? get fournisseurSelectionne =>
      fournisseurId.value == null
          ? null
          : fournisseurs.firstWhereOrNull((f) => f.id == fournisseurId.value);

  String get fournisseurLabel =>
      fournisseurSelectionne?.nom ?? 'Choisir un fournisseur';

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: scope, actives: true),
    );
    fournisseurs.bindStream(_fournRepo.watchScoped(scope));

    ever(currentBoutiqueId, (String? id) {
      if (id == null || id.isEmpty) return;
      _resetAppro();
      isLoadingProduits.value = true;
      produits.bindStream(
        _produitRepo.watchAll(boutiqueId: id, onlyActive: true),
      );
      debounce(produits, (_) => isLoadingProduits.value = false,
          time: const Duration(milliseconds: 200));
    });

    final user = UserController.to.user;
    if ((user?.isVendeur ?? false) || (user?.isAdmin ?? false)) {
      // Vendeur OU admin : verrouillé sur la boutique ACTIVE (et non la
      // boutique principale) pour qu'un admin multi-boutique scope bien
      // appro / produits / fournisseurs sur la boutique sélectionnée.
      final bId = UserController.to.scopeBoutiqueId;
      if (bId != null && bId.isNotEmpty) {
        currentBoutiqueId.value = bId;
      }
    } else {
      ever<List<BoutiqueModel>>(boutiques, (list) {
        if (currentBoutiqueId.value == null && list.isNotEmpty) {
          currentBoutiqueId.value = list.first.id;
        }
      });
    }

    ever(lignes, (_) => _autoSyncMontantPaye());
    ever(remiseGlobale, (_) => _autoSyncMontantPaye());

    // Pré-sélection fournisseur si on arrive depuis la fiche fournisseur
    final arg = Get.arguments;
    if (arg is FournisseurModel) {
      fournisseurId.value = arg.id;
    }
  }

  void _resetAppro() {
    lignes.clear();
    fournisseurId.value = null;
    remiseGlobale.value = 0;
    modePaiement.value = ModePaiement.especes;
    note.value = '';
    montantPaye.value = 0;
    avanceUtilisee.value = 0;
    _montantPayeAuto.value = true;
  }

  void _autoSyncMontantPaye() {
    final maxApp = avanceMaxApplicable;
    if (avanceUtilisee.value > maxApp) {
      avanceUtilisee.value = maxApp;
    }
    if (_montantPayeAuto.value) {
      montantPaye.value = total - avanceUtilisee.value;
    }
  }

  void setMontantPaye(double value) {
    _montantPayeAuto.value = false;
    montantPaye.value = value < 0 ? 0 : value;
  }

  void resetMontantPayeAuto() {
    _montantPayeAuto.value = true;
    montantPaye.value = total;
  }

  /// Reste à payer après cet appro (positif = nouvelle dette,
  /// négatif = trop-versé qui devient avance fournisseur).
  double get resteAPayer => total - montantPaye.value - avanceUtilisee.value;

  /// Avance disponible chez le fournisseur (= -solde si solde négatif).
  double get avanceDisponible {
    final f = fournisseurSelectionne;
    if (f == null) return 0;
    return f.solde < 0 ? -f.solde : 0;
  }

  /// Avance maximum applicable à cet appro (bornée par le total).
  double get avanceMaxApplicable {
    final dispo = avanceDisponible;
    return dispo > total ? total : dispo;
  }

  void appliquerAvanceMax() {
    final maxApp = avanceMaxApplicable;
    avanceUtilisee.value = maxApp;
    _montantPayeAuto.value = false;
    montantPaye.value = total - maxApp;
  }

  void setAvanceUtilisee(double value) {
    if (value < 0) value = 0;
    final maxApp = avanceMaxApplicable;
    if (value > maxApp) value = maxApp;
    avanceUtilisee.value = value;
    if (_montantPayeAuto.value) {
      montantPaye.value = total - value;
    }
  }

  void retirerAvance() {
    avanceUtilisee.value = 0;
    _montantPayeAuto.value = true;
    montantPaye.value = total;
  }

  // ===== Fournisseur =====
  void selectFournisseur(String? id) {
    fournisseurId.value = id;
    avanceUtilisee.value = 0;
    _autoSyncMontantPaye();
  }

  // ===== Lignes =====
  /// Ajoute une nouvelle ligne. Le PA peut être différent du PA actuel
  /// du produit (le fournisseur facture parfois différemment) — c'est ce
  /// PA qui entrera dans le calcul du CMUP. Pour un produit à variantes,
  /// passer `varianteId` + `varianteLibelle`.
  bool addLigne({
    required ProduitModel produit,
    required int quantite,
    required double prixAchatUnitaire,
    String? varianteId,
    String? varianteLibelle,
  }) {
    if (quantite <= 0) {
      _snackError('Quantité invalide');
      return false;
    }
    if (prixAchatUnitaire <= 0) {
      _snackError('Prix d\'achat invalide');
      return false;
    }
    if (produit.hasVariantes && (varianteId == null || varianteId.isEmpty)) {
      _snackError('Sélectionnez une variante (pointure / taille).');
      return false;
    }
    // Dédoublonnage par (produitId, varianteId)
    final dejaPresent = lignes.any(
      (l) => l.produit.id == produit.id && l.varianteId == varianteId,
    );
    if (dejaPresent) {
      final lib = varianteLibelle == null || varianteLibelle.isEmpty
          ? produit.nom
          : '${produit.nom} — $varianteLibelle';
      _snackError(
        '$lib est déjà dans cet appro. Modifiez la quantité ou '
        'le prix sur la ligne existante.',
      );
      return false;
    }
    lignes.add(LigneAppro(
      produit: produit,
      quantite: quantite,
      prixAchatUnitaire: prixAchatUnitaire,
      varianteId: varianteId,
      varianteLibelle: varianteLibelle,
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

  void setQuantiteLigne(int index, int q) {
    if (q <= 0) {
      lignes.removeAt(index);
      return;
    }
    lignes[index].quantite = q;
    lignes.refresh();
  }

  void setPrixAchatLigne(int index, double pa) {
    if (pa <= 0) return;
    lignes[index].prixAchatUnitaire = pa;
    lignes.refresh();
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
  Future<void> validerAppro() async {
    if (lignes.isEmpty) {
      _snackError('Ajoutez au moins une ligne');
      return;
    }
    if (currentBoutiqueId.value == null) {
      _snackError('Aucune boutique sélectionnée');
      return;
    }
    if (fournisseurId.value == null || fournisseurId.value!.isEmpty) {
      _snackError('Sélectionnez un fournisseur');
      return;
    }
    final userId = UserController.to.user?.id;
    if (userId == null) {
      _snackError('Session expirée');
      return;
    }

    isSaving.value = true;
    try {
      final appro = ApprovisionnementModel(
        id: '',
        boutiqueId: currentBoutiqueId.value!,
        userId: userId,
        fournisseurId: fournisseurId.value!,
        articles: lignes.map((l) => l.toApproArticle()).toList(),
        sousTotal: sousTotal,
        remise: remiseGlobale.value,
        total: total,
        montantPaye: montantPaye.value,
        avanceUtilisee: avanceUtilisee.value,
        modePaiement: modePaiement.value,
        date: DateTime.now(),
        note: note.value.isEmpty ? null : note.value,
      );

      final approId = await _approRepo.create(appro);

      _resetAppro();
      Get.back();
      Get.snackbar(
        'Appro enregistré',
        'Total : ${appro.total.toStringAsFixed(0)} $devise',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      Get.toNamed(AppRoutes.approDetail, arguments: approId);
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
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
    );
  }
}
