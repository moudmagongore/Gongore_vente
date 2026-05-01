import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/user_controller.dart';
import '../../../data/models/boutique_model.dart';
import '../../../data/models/produit_model.dart';
import '../../../data/models/stock_model.dart';
import '../../../data/models/vente_model.dart';
import '../../../data/repositories/boutique_repository.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/repositories/categorie_repository.dart';
import '../../../data/repositories/produit_repository.dart';
import '../../../data/repositories/stock_repository.dart';
import '../../../data/repositories/vente_repository.dart';
import '../../../routes/app_routes.dart';

class CartLine {
  final ProduitModel produit;
  int quantite;
  double remise;

  CartLine({
    required this.produit,
    this.quantite = 1,
    this.remise = 0,
  });

  double get prixUnitaire => produit.prixVente;
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

class PosController extends GetxController {
  final ProduitRepository _produitRepo = ProduitRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final CategorieRepository _catRepo = CategorieRepository();
  final StockRepository _stockRepo = StockRepository();
  final VenteRepository _venteRepo = VenteRepository();

  // ======== Boutique courante ========
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxnString currentBoutiqueId = RxnString();

  // ======== Catalogue ========
  final RxList<ProduitModel> _produits = <ProduitModel>[].obs;
  final RxList<StockModel> _stocks = <StockModel>[].obs;
  final RxList<CategorieModel> categories = <CategorieModel>[].obs;
  final RxString search = ''.obs;
  final RxnString filterCategorieId = RxnString();
  final RxBool isLoadingProduits = true.obs;

  // ======== Panier ========
  final RxList<CartLine> cart = <CartLine>[].obs;
  final RxDouble remiseGlobale = 0.0.obs;
  final Rx<ModePaiement> modePaiement = ModePaiement.especes.obs;

  // ======== Validation ========
  final RxBool isSaving = false.obs;

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

  @override
  void onInit() {
    super.onInit();
    // ignore: avoid_print
    print('[PosController] onInit START');
    final scope = UserController.to.scopeBoutiqueId;
    // ignore: avoid_print
    print('[PosController] scope=$scope, user=${UserController.to.user?.email}, role=${UserController.to.user?.role.name}');

    // Streams avec handleError pour qu'une permission denied ne crash pas l'app
    boutiques.bindStream(
      _boutiqueRepo
          .watchScoped(scope: scope, actives: true)
          .handleError((e) {
        _logStreamError('boutiques', e);
      }),
    );
    categories.bindStream(
      _catRepo.watchAll(boutiqueId: scope).handleError((e) {
        _logStreamError('categories', e);
      }),
    );

    // ⚠️ Ce listener doit être enregistré AVANT toute affectation de
    // currentBoutiqueId (sinon l'init synchrone du vendeur/admin ne déclenche
    // pas le bind des produits/stocks).
    ever(currentBoutiqueId, (String? id) {
      if (id == null || id.isEmpty) return;
      cart.clear();
      isLoadingProduits.value = true;
      _produits.bindStream(
        _produitRepo
            .watchAll(boutiqueId: id, onlyActive: true)
            .handleError((e) {
          _logStreamError('produits', e);
          isLoadingProduits.value = false;
        }),
      );
      _stocks.bindStream(
        _stockRepo.watchByBoutique(id).handleError((e) {
          _logStreamError('stocks', e);
        }),
      );
      debounce(_produits, (_) => isLoadingProduits.value = false,
          time: const Duration(milliseconds: 200));
    });

    // Initialise la boutique selon le rôle
    final user = UserController.to.user;
    if ((user?.isVendeur ?? false) || (user?.isAdmin ?? false)) {
      // Vendeur OU admin de boutique : verrouillé sur sa boutique
      final bId = user?.boutiqueId;
      if (bId != null && bId.isNotEmpty) {
        currentBoutiqueId.value = bId;
      }
    } else {
      // Super-admin : sélectionne la 1re boutique disponible
      ever<List<BoutiqueModel>>(boutiques, (list) {
        if (currentBoutiqueId.value == null && list.isNotEmpty) {
          currentBoutiqueId.value = list.first.id;
        }
      });
    }
  }

  void _logStreamError(String source, Object error) {
    // ignore: avoid_print
    print('[PosController] Erreur stream "$source" : $error');
    Get.snackbar(
      'Erreur de chargement',
      'Impossible de charger $source : $error',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 5),
    );
  }

  // ======== Recherche / catalogue ========
  int stockOf(String produitId) {
    return _stocks
            .firstWhereOrNull((s) => s.produitId == produitId)
            ?.quantite ??
        0;
  }

  List<ProduitModel> get filtredProduits {
    final q = search.value.trim().toLowerCase();
    return _produits.where((p) {
      if (filterCategorieId.value != null &&
          p.categorieId != filterCategorieId.value) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.nom.toLowerCase().contains(q) ||
          (p.codeBarre?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ======== Panier ========
  void addToCart(ProduitModel p) {
    final stock = stockOf(p.id);
    if (stock <= 0) {
      _snackError('« ${p.nom} » est en rupture de stock');
      return;
    }

    final existingIndex = cart.indexWhere((l) => l.produit.id == p.id);
    if (existingIndex >= 0) {
      final line = cart[existingIndex];
      if (line.quantite + 1 > stock) {
        _snackError('Stock limité à $stock pour « ${p.nom} »');
        return;
      }
      line.quantite++;
      cart.refresh();
    } else {
      cart.add(CartLine(produit: p));
    }
  }

  void incrementLine(int index) {
    final line = cart[index];
    final stock = stockOf(line.produit.id);
    if (line.quantite + 1 > stock) {
      _snackError('Stock limité à $stock');
      return;
    }
    line.quantite++;
    cart.refresh();
  }

  void decrementLine(int index) {
    final line = cart[index];
    if (line.quantite <= 1) {
      cart.removeAt(index);
    } else {
      line.quantite--;
      cart.refresh();
    }
  }

  void setLineQuantity(int index, int qty) {
    if (qty <= 0) {
      cart.removeAt(index);
      return;
    }
    final line = cart[index];
    final stock = stockOf(line.produit.id);
    line.quantite = qty > stock ? stock : qty;
    cart.refresh();
  }

  void setLineRemise(int index, double remise) {
    final line = cart[index];
    final max = line.sousTotalBrut;
    line.remise = remise < 0 ? 0 : (remise > max ? max : remise);
    cart.refresh();
  }

  void setLineRemisePourcent(int index, double pourcent) {
    final p = pourcent.clamp(0, 100).toDouble();
    setLineRemise(index, cart[index].sousTotalBrut * p / 100);
  }

  void removeLine(int index) {
    cart.removeAt(index);
  }

  void clearCart() {
    cart.clear();
    remiseGlobale.value = 0;
  }

  // ======== Totaux ========
  double get sousTotal => cart.fold(0.0, (acc, l) => acc + l.sousTotal);
  double get total {
    final t = sousTotal - remiseGlobale.value;
    return t < 0 ? 0 : t;
  }

  int get nbArticles => cart.fold(0, (acc, l) => acc + l.quantite);

  // ======== Validation ========
  Future<void> validerVente() async {
    if (cart.isEmpty) {
      _snackError('Panier vide');
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

    isSaving.value = true;
    try {
      final vente = VenteModel(
        id: '',
        boutiqueId: currentBoutiqueId.value!,
        vendeurId: userId,
        articles: cart.map((l) => l.toVenteArticle()).toList(),
        sousTotal: sousTotal,
        remise: remiseGlobale.value,
        total: total,
        modePaiement: modePaiement.value,
        date: DateTime.now(),
      );

      final venteId = await _venteRepo.create(vente);

      // Reset
      clearCart();
      modePaiement.value = ModePaiement.especes;

      Get.back(); // ferme la modale panier si ouverte
      Get.snackbar(
        'Vente validée ✅',
        'Total : ${vente.total.toStringAsFixed(0)} $devise',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      // Naviguer vers le détail (option : afficher reçu)
      await Future.delayed(const Duration(milliseconds: 200));
      Get.toNamed(AppRoutes.venteDetail, arguments: venteId);
    } on StockInsuffisantException catch (e) {
      _snackError(e.message);
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
