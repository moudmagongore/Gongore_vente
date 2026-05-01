import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/stock_repository.dart';

/// Controller du formulaire de mouvement de stock
/// (entrée, sortie, transfert, ajustement).
class MouvementController extends GetxController {
  final StockRepository _stockRepo = StockRepository();
  final ProduitRepository _produitRepo = ProduitRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();

  /// Type de mouvement: entree | sortie | transfert | ajustement
  /// (sortie englobe perte/casse via un sous-choix)
  final Rx<MouvementType> type = MouvementType.entree.obs;

  /// Pour les sorties: type effectif (sortie / perte / casse)
  final Rx<MouvementType> sortieType = MouvementType.sortie.obs;

  final RxnString boutiqueId = RxnString();
  final RxnString boutiqueDestId = RxnString(); // pour transferts
  final RxnString produitId = RxnString();

  final quantiteCtrl = TextEditingController();
  final motifCtrl = TextEditingController();

  final RxList<ProduitModel> produits = <ProduitModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxInt stockActuel = 0.obs;
  final RxBool isSaving = false.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  /// Admin de boutique : pas de transfert possible (il ne voit pas
  /// les autres boutiques).
  bool get canTransfert =>
      isSuperAdmin || UserController.to.user?.role == UserRole.admin;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(
      scope: UserController.to.scopeBoutiqueId,
      actives: true,
    ));

    // Pré-sélection éventuelle via arguments (typeForcé, boutiqueId, produitId)
    final args = Get.arguments;
    if (args is Map) {
      if (args['type'] is MouvementType) {
        type.value = args['type'] as MouvementType;
      }
      if (args['boutiqueId'] is String) {
        boutiqueId.value = args['boutiqueId'] as String;
      }
      if (args['produitId'] is String) {
        produitId.value = args['produitId'] as String;
      }
    }

    // Admin de boutique : forcer la boutique source à la sienne
    if (!isSuperAdmin) {
      boutiqueId.value = UserController.to.boutiqueId;
    }

    // Recharger les produits quand la boutique change
    ever(boutiqueId, (String? id) {
      if (id == null) {
        produits.clear();
        return;
      }
      produits.bindStream(
        _produitRepo.watchAll(boutiqueId: id, onlyActive: true),
      );
      _refreshStockActuel();
    });

    ever(produitId, (_) => _refreshStockActuel());
  }

  @override
  void onClose() {
    quantiteCtrl.dispose();
    motifCtrl.dispose();
    super.onClose();
  }

  Future<void> _refreshStockActuel() async {
    if (boutiqueId.value == null || produitId.value == null) {
      stockActuel.value = 0;
      return;
    }
    final s = await _stockRepo.getOne(boutiqueId.value!, produitId.value!);
    stockActuel.value = s?.quantite ?? 0;
  }

  String get title {
    switch (type.value) {
      case MouvementType.entree:
        return 'Entrée de stock';
      case MouvementType.sortie:
      case MouvementType.perte:
      case MouvementType.casse:
        return 'Sortie de stock';
      case MouvementType.transfert:
        return 'Transfert entre boutiques';
      case MouvementType.ajustement:
        return 'Ajustement d\'inventaire';
      case MouvementType.vente:
        return 'Vente';
    }
  }

  bool get needsDestination => type.value == MouvementType.transfert;

  // ============== Validators ==============
  String? validateBoutique(String? v) {
    if (v == null || v.isEmpty) return 'Boutique requise';
    return null;
  }

  String? validateBoutiqueDest(String? v) {
    if (!needsDestination) return null;
    if (v == null || v.isEmpty) return 'Boutique de destination requise';
    if (v == boutiqueId.value) return 'Doit différer de la source';
    return null;
  }

  String? validateProduit(String? v) {
    if (v == null || v.isEmpty) return 'Produit requis';
    return null;
  }

  String? validateQuantite(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Quantité requise';
    final n = int.tryParse(value);
    if (n == null) return 'Nombre entier requis';
    if (type.value == MouvementType.ajustement) {
      if (n < 0) return 'Quantité ≥ 0';
    } else {
      if (n <= 0) return 'Quantité > 0';
    }
    return null;
  }

  String? validateMotif(String? v) {
    if (type.value == MouvementType.ajustement && (v == null || v.trim().isEmpty)) {
      return 'Motif requis pour un ajustement';
    }
    return null;
  }

  // ============== Save ==============
  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (validateBoutique(boutiqueId.value) != null) {
      _snackError(validateBoutique(boutiqueId.value)!);
      return;
    }
    final destErr = validateBoutiqueDest(boutiqueDestId.value);
    if (destErr != null) {
      _snackError(destErr);
      return;
    }
    if (validateProduit(produitId.value) != null) {
      _snackError(validateProduit(produitId.value)!);
      return;
    }

    final qte = int.parse(quantiteCtrl.text.trim());
    final userId = UserController.to.user?.id;
    if (userId == null) {
      _snackError('Session expirée');
      return;
    }
    final motif = motifCtrl.text.trim().isEmpty ? null : motifCtrl.text.trim();

    isSaving.value = true;
    try {
      switch (type.value) {
        case MouvementType.entree:
          await _stockRepo.entree(
            boutiqueId: boutiqueId.value!,
            produitId: produitId.value!,
            quantite: qte,
            userId: userId,
            motif: motif,
          );
          break;
        case MouvementType.sortie:
        case MouvementType.perte:
        case MouvementType.casse:
          await _stockRepo.sortie(
            boutiqueId: boutiqueId.value!,
            produitId: produitId.value!,
            quantite: qte,
            type: sortieType.value,
            userId: userId,
            motif: motif,
          );
          break;
        case MouvementType.transfert:
          await _stockRepo.transfert(
            produitId: produitId.value!,
            boutiqueSourceId: boutiqueId.value!,
            boutiqueDestinationId: boutiqueDestId.value!,
            quantite: qte,
            userId: userId,
            motif: motif,
          );
          break;
        case MouvementType.ajustement:
          await _stockRepo.ajustement(
            boutiqueId: boutiqueId.value!,
            produitId: produitId.value!,
            nouvelleQuantite: qte,
            userId: userId,
            motif: motif!,
          );
          break;
        case MouvementType.vente:
          // Pas géré ici (c'est l'écran de vente qui appelle)
          break;
      }

      Get.back();
      Get.snackbar(
        'Mouvement enregistré',
        title,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on StockInsuffisantException catch (e) {
      _snackError(e.message);
    } catch (e) {
      _snackError('Erreur : $e');
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
