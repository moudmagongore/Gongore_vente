import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/variante_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';
import '../../../../data/repositories/produit_repository.dart';

/// Ligne de variante côté UI (binding avec contrôleurs de texte).
/// Conserve l'`id` Firestore quand la variante existe déjà, ou vide pour
/// les nouvelles lignes (créées via `+ Ligne`).
class VarianteEditable {
  String id;
  final TextEditingController libelleCtrl;
  final TextEditingController couleurCtrl;
  final TextEditingController stockCtrl;

  VarianteEditable({
    String? id,
    String libelle = '',
    String couleur = '',
    int stock = 0,
  })  : id = id ?? '',
        libelleCtrl = TextEditingController(text: libelle),
        couleurCtrl = TextEditingController(text: couleur),
        stockCtrl = TextEditingController(text: stock == 0 ? '' : '$stock');

  int get stock => int.tryParse(stockCtrl.text.trim()) ?? 0;
  String get libelle => libelleCtrl.text.trim();
  String get couleur => couleurCtrl.text.trim();

  void dispose() {
    libelleCtrl.dispose();
    couleurCtrl.dispose();
    stockCtrl.dispose();
  }
}

class ProduitFormController extends GetxController {
  final ProduitRepository _repo = ProduitRepository();
  final CategorieRepository _catRepo = CategorieRepository();
  final BoutiqueRepository _boutRepo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final prixAchatCtrl = TextEditingController();
  final prixVenteCtrl = TextEditingController();
  final seuilCtrl = TextEditingController(text: '5');

  /// Quantité initiale en stock — visible uniquement à la **création**
  /// d'un produit **sans** variantes. À l'édition, le stock est géré
  /// uniquement via les appros / mouvements / ventes.
  final stockInitialCtrl = TextEditingController(text: '0');

  final RxnString categorieId = RxnString();
  final RxnString boutiqueId = RxnString();
  final RxBool active = true.obs;

  final RxList<CategorieModel> categories = <CategorieModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isSaving = false.obs;

  final Rxn<ProduitModel> editing = Rxn<ProduitModel>();

  // ============== Variantes ==============
  /// Toggle "Avec variantes" — bascule entre stock simple et liste de
  /// variantes (pointures, tailles, ...).
  final RxBool hasVariantes = false.obs;

  /// Lignes de variantes éditables. Quand vide et `hasVariantes=true`,
  /// l'enregistrement échoue (au moins 1 ligne requise).
  final RxList<VarianteEditable> variantes = <VarianteEditable>[].obs;

  /// Somme live des stocks saisis dans les lignes de variantes.
  /// Réactif via [variantes] mais on expose aussi un compteur recalculé
  /// par les onChanged sur les TextField.
  final RxInt variantesTotalStock = 0.obs;

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
      prixAchatCtrl.text = arg.prixAchat == 0 ? '' : arg.prixAchat.toString();
      prixVenteCtrl.text = arg.prixVente.toString();
      seuilCtrl.text = arg.seuilAlerte.toString();
      categorieId.value = arg.categorieId;
      boutiqueId.value = arg.boutiqueId;
      active.value = arg.active;
      hasVariantes.value = arg.hasVariantes;
      if (arg.hasVariantes) {
        _loadExistingVariantes(arg.id);
      }
    } else if (!canPickBoutique) {
      // Admin de boutique : pré-remplir sa boutique
      boutiqueId.value = UserController.to.boutiqueId;
    }
  }

  Future<void> _loadExistingVariantes(String produitId) async {
    final list = await _repo.listVariantes(produitId);
    variantes.assignAll(list.map(
      (v) => VarianteEditable(
        id: v.id,
        libelle: v.libelle,
        couleur: v.couleur ?? '',
        stock: v.stock,
      ),
    ));
    _recomputeTotalStock();
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    descCtrl.dispose();
    prixAchatCtrl.dispose();
    prixVenteCtrl.dispose();
    seuilCtrl.dispose();
    stockInitialCtrl.dispose();
    for (final v in variantes) {
      v.dispose();
    }
    super.onClose();
  }

  // ============== Actions variantes ==============
  /// Bascule "Avec variantes". Si on active et qu'il n'y a aucune ligne,
  /// on en crée une vide pour amorcer la saisie.
  void toggleHasVariantes(bool v) {
    hasVariantes.value = v;
    if (v && variantes.isEmpty) {
      addVarianteLigne();
    }
  }

  void addVarianteLigne() {
    variantes.add(VarianteEditable());
    _recomputeTotalStock();
  }

  void removeVarianteLigne(int index) {
    if (index < 0 || index >= variantes.length) return;
    final removed = variantes.removeAt(index);
    removed.dispose();
    _recomputeTotalStock();
  }

  /// À appeler depuis les `onChanged` des TextField stock pour rafraîchir
  /// le total affiché.
  void _recomputeTotalStock() {
    var total = 0;
    for (final v in variantes) {
      total += v.stock;
    }
    variantesTotalStock.value = total;
  }

  /// Hook public utilisé par la vue dans onChanged du champ stock.
  void onVarianteStockChanged() => _recomputeTotalStock();

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

  String? validateBoutique(String? v) {
    if (v == null || v.isEmpty) return 'Boutique requise';
    return null;
  }

  String? validateSeuil(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Nombre entier ≥ 0';
    return null;
  }

  // ============== Save ==============
  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (validateBoutique(boutiqueId.value) != null) {
      _snackError('Sélectionnez une boutique');
      return;
    }

    // Validation variantes : si activé, au moins 1 ligne, libellés non vides
    // et libellés uniques.
    if (hasVariantes.value) {
      if (variantes.isEmpty) {
        _snackError('Ajoutez au moins une variante.');
        return;
      }
      final libelles = <String>{};
      for (final v in variantes) {
        if (v.libelle.isEmpty) {
          _snackError('Chaque variante doit avoir un libellé.');
          return;
        }
        if (!libelles.add(v.libelle.toLowerCase())) {
          _snackError('Libellé en double : ${v.libelle}');
          return;
        }
      }
      // Vérouille la conversion en mode "simple → variantes" si le produit
      // a déjà du stock (interdit pour éviter la migration des mouvements).
      if (isEdit && !editing.value!.hasVariantes &&
          editing.value!.quantiteStock > 0) {
        _snackError(
            'Impossible d\'activer les variantes : ce produit a déjà du stock. '
            'Ramenez le stock à 0 d\'abord.');
        return;
      }
    } else {
      // Inverse : interdit aussi de désactiver les variantes si le produit
      // en a déjà avec du stock (perdrait l'historique implicite).
      if (isEdit && editing.value!.hasVariantes &&
          editing.value!.quantiteStock > 0) {
        _snackError(
            'Impossible de désactiver les variantes : ce produit a du stock '
            'rattaché aux variantes. Videz les stocks d\'abord.');
        return;
      }
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

      // Construit la liste des variantes (modèle Firestore) à partir des
      // lignes éditées. Conserve l'id existant si présent.
      final varianteModels = hasVariantes.value
          ? variantes
              .map(
                (v) => VarianteModel(
                  id: v.id,
                  libelle: v.libelle,
                  couleur: v.couleur.isEmpty ? null : v.couleur,
                  stock: v.stock,
                ),
              )
              .toList()
          : <VarianteModel>[];

      if (isEdit) {
        final updated = editing.value!.copyWith(
          nom: nomCtrl.text.trim(),
          description:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          prixAchat: prixAchat,
          prixVente: prixVente,
          categorieId: categorieId.value,
          boutiqueId: boutiqueId.value!,
          seuilAlerte: seuil,
          hasVariantes: hasVariantes.value,
          // quantiteStock sera réécrit par syncVariantes si avec variantes ;
          // pour le mode simple, conserve la valeur actuelle.
          active: active.value,
        );
        await _repo.update(updated);

        if (hasVariantes.value) {
          await _repo.syncVariantes(
            produitId: updated.id,
            variantes: varianteModels,
          );
        } else if (editing.value!.hasVariantes) {
          // Bascule variantes → simple : purge la sous-collection.
          await _repo.syncVariantes(
            produitId: updated.id,
            variantes: const <VarianteModel>[],
          );
        }

        Get.back();
        Get.snackbar('Modifications enregistrées', updated.nom,
            snackPosition: SnackPosition.TOP);
      } else {
        // Stock initial : variantes → somme des stocks ; sinon → champ saisi.
        final stockInitial = hasVariantes.value
            ? variantesTotalStock.value
            : (int.tryParse(stockInitialCtrl.text.trim()) ?? 0);
        final newProd = ProduitModel(
          id: '',
          nom: nomCtrl.text.trim(),
          description:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          prixAchat: prixAchat,
          prixVente: prixVente,
          categorieId: categorieId.value,
          boutiqueId: boutiqueId.value!,
          quantiteStock: stockInitial,
          seuilAlerte: seuil,
          hasVariantes: hasVariantes.value,
          active: active.value,
        );
        final newId = await _repo.create(newProd);

        if (hasVariantes.value) {
          await _repo.syncVariantes(
            produitId: newId,
            variantes: varianteModels,
          );
        }

        Get.back();
        Get.snackbar(
          'Produit créé',
          newProd.nom,
          snackPosition: SnackPosition.TOP,
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
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
    );
  }
}
