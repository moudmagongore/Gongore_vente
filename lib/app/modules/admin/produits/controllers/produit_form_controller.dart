import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/stock_repository.dart';

class ProduitFormController extends GetxController {
  final ProduitRepository _repo = ProduitRepository();
  final CategorieRepository _catRepo = CategorieRepository();
  final BoutiqueRepository _boutRepo = BoutiqueRepository();
  final StockRepository _stockRepo = StockRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final codeBarreCtrl = TextEditingController();
  final prixAchatCtrl = TextEditingController();
  final prixVenteCtrl = TextEditingController();
  final uniteCtrl = TextEditingController();
  final seuilCtrl = TextEditingController(text: '5');
  final stockInitialCtrl = TextEditingController();

  final RxnString categorieId = RxnString();
  final RxnString boutiqueId = RxnString();
  final RxBool active = true.obs;

  final RxList<CategorieModel> categories = <CategorieModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isSaving = false.obs;

  final Rxn<ProduitModel> editing = Rxn<ProduitModel>();

  bool get isEdit => editing.value != null;
  String get title => isEdit ? 'Modifier le produit' : 'Nouveau produit';

  /// Super-admin peut choisir la boutique. Admin de boutique : verrouillée.
  bool get canPickBoutique => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    categories.bindStream(_catRepo.watchAll(boutiqueId: scope));
    boutiques.bindStream(
      _boutRepo.watchScoped(scope: scope, actives: true),
    );

    final arg = Get.arguments;
    if (arg is ProduitModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      descCtrl.text = arg.description ?? '';
      codeBarreCtrl.text = arg.codeBarre ?? '';
      prixAchatCtrl.text = arg.prixAchat == 0 ? '' : arg.prixAchat.toString();
      prixVenteCtrl.text = arg.prixVente.toString();
      uniteCtrl.text = arg.unite ?? '';
      seuilCtrl.text = arg.seuilAlerte.toString();
      categorieId.value = arg.categorieId;
      boutiqueId.value = arg.boutiqueId;
      active.value = arg.active;
      _loadCurrentStock(arg.boutiqueId, arg.id);
    } else if (!canPickBoutique) {
      // Admin de boutique : pré-remplir sa boutique
      boutiqueId.value = UserController.to.boutiqueId;
    }
  }

  Future<void> _loadCurrentStock(String bId, String pId) async {
    final stock = await _stockRepo.getOne(bId, pId);
    stockInitialCtrl.text = (stock?.quantite ?? 0).toString();
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    descCtrl.dispose();
    codeBarreCtrl.dispose();
    prixAchatCtrl.dispose();
    prixVenteCtrl.dispose();
    uniteCtrl.dispose();
    seuilCtrl.dispose();
    stockInitialCtrl.dispose();
    super.onClose();
  }

  // ============== Validators ==============
  String? validateNom(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Nom requis';
    if (value.length < 2) return 'Au moins 2 caractères';
    return null;
  }

  String? validatePrixVente(String? v) {
    final value = v?.trim().replaceAll(',', '.') ?? '';
    if (value.isEmpty) return 'Prix de vente requis';
    final n = double.tryParse(value);
    if (n == null || n <= 0) return 'Prix invalide';
    return null;
  }

  String? validatePrixAchat(String? v) {
    final value = v?.trim().replaceAll(',', '.') ?? '';
    if (value.isEmpty) return null;
    final n = double.tryParse(value);
    if (n == null || n < 0) return 'Prix invalide';
    return null;
  }

  String? validateSeuil(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Nombre entier ≥ 0';
    return null;
  }

  String? validateStockInitial(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Quantité requise';
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Nombre entier ≥ 0';
    return null;
  }

  String? validateBoutique(String? v) {
    if (v == null || v.isEmpty) return 'Boutique requise';
    return null;
  }

  // ============== Save ==============
  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (validateBoutique(boutiqueId.value) != null) {
      _snackError('Sélectionnez une boutique');
      return;
    }

    isSaving.value = true;
    try {
      final prixAchat = double.tryParse(
            prixAchatCtrl.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      final prixVente = double.parse(
        prixVenteCtrl.text.trim().replaceAll(',', '.'),
      );
      final seuil = int.tryParse(seuilCtrl.text.trim()) ?? 5;

      if (isEdit) {
        final updated = editing.value!.copyWith(
          nom: nomCtrl.text.trim(),
          description:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          codeBarre: codeBarreCtrl.text.trim().isEmpty
              ? null
              : codeBarreCtrl.text.trim(),
          prixAchat: prixAchat,
          prixVente: prixVente,
          categorieId: categorieId.value,
          unite: uniteCtrl.text.trim().isEmpty ? null : uniteCtrl.text.trim(),
          boutiqueId: boutiqueId.value!,
          seuilAlerte: seuil,
          active: active.value,
        );
        await _repo.update(updated);

        // Si la quantité a changé, on enregistre un ajustement (traçable)
        final newQte =
            int.tryParse(stockInitialCtrl.text.trim()) ?? 0;
        final currentStock = await _stockRepo.getOne(
          updated.boutiqueId,
          updated.id,
        );
        final currentQte = currentStock?.quantite ?? 0;
        if (newQte != currentQte) {
          final userId = UserController.to.user?.id;
          if (userId != null) {
            try {
              await _stockRepo.ajustement(
                boutiqueId: updated.boutiqueId,
                produitId: updated.id,
                nouvelleQuantite: newQte,
                userId: userId,
                motif: 'Ajustement via fiche produit',
              );
            } catch (_) {
              // Non bloquant
            }
          }
        }

        Get.back();
        Get.snackbar('Modifications enregistrées', updated.nom,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        final newProd = ProduitModel(
          id: '',
          nom: nomCtrl.text.trim(),
          description:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          codeBarre: codeBarreCtrl.text.trim().isEmpty
              ? null
              : codeBarreCtrl.text.trim(),
          prixAchat: prixAchat,
          prixVente: prixVente,
          categorieId: categorieId.value,
          unite: uniteCtrl.text.trim().isEmpty ? null : uniteCtrl.text.trim(),
          boutiqueId: boutiqueId.value!,
          seuilAlerte: seuil,
          active: active.value,
        );
        final newId = await _repo.create(newProd);

        // Création du stock initial si renseigné (avec traçabilité)
        final stockInitial =
            int.tryParse(stockInitialCtrl.text.trim()) ?? 0;
        if (stockInitial > 0) {
          final userId = UserController.to.user?.id;
          if (userId != null) {
            try {
              await _stockRepo.entree(
                boutiqueId: boutiqueId.value!,
                produitId: newId,
                quantite: stockInitial,
                userId: userId,
                motif: 'Stock initial à la création',
              );
            } catch (_) {
              // Non bloquant : le produit est créé même si le stock initial échoue
            }
          }
        }

        Get.back();
        Get.snackbar(
          'Produit créé',
          stockInitial > 0
              ? '${newProd.nom} (stock initial : $stockInitial)'
              : newProd.nom,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      _snackError('Enregistrement impossible : $e');
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
