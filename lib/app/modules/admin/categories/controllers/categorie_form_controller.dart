import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/categorie_repository.dart';

class CategorieFormController extends GetxController {
  final CategorieRepository _repo = CategorieRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  final RxnString boutiqueId = RxnString();
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isSaving = false.obs;
  final Rxn<CategorieModel> editing = Rxn<CategorieModel>();

  bool get isEdit => editing.value != null;
  String get title => isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie';
  bool get canPickBoutique => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(
      scope: UserController.to.scopeBoutiqueId,
      actives: true,
    ));

    final arg = Get.arguments;
    if (arg is CategorieModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      descCtrl.text = arg.description ?? '';
      boutiqueId.value = arg.boutiqueId;
    } else if (!canPickBoutique) {
      // Admin de boutique : pré-remplir sa boutique
      boutiqueId.value = UserController.to.scopeBoutiqueId;
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    descCtrl.dispose();
    super.onClose();
  }

  String? validateNom(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Nom requis';
    if (value.length < 2) return 'Au moins 2 caractères';
    return null;
  }

  String? validateBoutique(String? v) {
    if (v == null || v.isEmpty) return 'Boutique requise';
    return null;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final bId = boutiqueId.value;
    if (validateBoutique(bId) != null) {
      _snackError('Boutique requise');
      return;
    }

    isSaving.value = true;
    try {
      if (isEdit) {
        final updated = editing.value!.copyWith(
          nom: nomCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          boutiqueId: bId,
        );
        await _repo.update(updated);
        Get.back();
        Get.snackbar(
          'Modifications enregistrées',
          updated.nom,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        final newCat = CategorieModel(
          id: '',
          nom: nomCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          boutiqueId: bId,
        );
        await _repo.create(newCat);
        Get.back();
        Get.snackbar(
          'Catégorie créée',
          newCat.nom,
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
