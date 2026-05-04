import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';
import '../../../../data/repositories/produit_repository.dart';

class ProduitFormController extends GetxController {
  final ProduitRepository _repo = ProduitRepository();
  final CategorieRepository _catRepo = CategorieRepository();
  final BoutiqueRepository _boutRepo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final prixAchatCtrl = TextEditingController();
  final prixVenteCtrl = TextEditingController();
  final uniteCtrl = TextEditingController();
  final seuilCtrl = TextEditingController(text: '5');

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
      prixAchatCtrl.text = arg.prixAchat == 0 ? '' : arg.prixAchat.toString();
      prixVenteCtrl.text = arg.prixVente.toString();
      uniteCtrl.text = arg.unite ?? '';
      seuilCtrl.text = arg.seuilAlerte.toString();
      categorieId.value = arg.categorieId;
      boutiqueId.value = arg.boutiqueId;
      active.value = arg.active;
    } else if (!canPickBoutique) {
      // Admin de boutique : pré-remplir sa boutique
      boutiqueId.value = UserController.to.boutiqueId;
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    descCtrl.dispose();
    prixAchatCtrl.dispose();
    prixVenteCtrl.dispose();
    uniteCtrl.dispose();
    seuilCtrl.dispose();
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
          prixAchat: prixAchat,
          prixVente: prixVente,
          categorieId: categorieId.value,
          unite: uniteCtrl.text.trim().isEmpty ? null : uniteCtrl.text.trim(),
          boutiqueId: boutiqueId.value!,
          seuilAlerte: seuil,
          active: active.value,
        );
        await _repo.update(updated);

        Get.back();
        Get.snackbar('Modifications enregistrées', updated.nom,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        final newProd = ProduitModel(
          id: '',
          nom: nomCtrl.text.trim(),
          description:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          prixAchat: prixAchat,
          prixVente: prixVente,
          categorieId: categorieId.value,
          unite: uniteCtrl.text.trim().isEmpty ? null : uniteCtrl.text.trim(),
          boutiqueId: boutiqueId.value!,
          seuilAlerte: seuil,
          active: active.value,
        );
        await _repo.create(newProd);

        Get.back();
        Get.snackbar(
          'Produit créé',
          newProd.nom,
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
