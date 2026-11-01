import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/nature_depense_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/nature_depense_repository.dart';

class NatureDepenseFormController extends GetxController {
  final NatureDepenseRepository _repo = NatureDepenseRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  final RxnString boutiqueId = RxnString();
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxBool active = true.obs;

  final RxBool isSaving = false.obs;
  final Rxn<NatureDepenseModel> editing = Rxn<NatureDepenseModel>();

  bool get isEdit => editing.value != null;
  String get title =>
      isEdit ? 'Modifier la nature' : 'Nouvelle nature de dépense';
  bool get canPickBoutique => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(
      scope: UserController.to.scopeBoutiqueId,
      actives: true,
    ));

    final arg = Get.arguments;
    if (arg is NatureDepenseModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      descCtrl.text = arg.description ?? '';
      boutiqueId.value = arg.boutiqueId;
      active.value = arg.active;
    } else if (!canPickBoutique) {
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

    final desc =
        descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();

    isSaving.value = true;
    try {
      if (isEdit) {
        final updated = NatureDepenseModel(
          id: editing.value!.id,
          nom: nomCtrl.text.trim(),
          description: desc,
          boutiqueId: bId!,
          active: active.value,
          createdAt: editing.value!.createdAt,
        );
        await _repo.update(updated);
        Get.back();
        Get.snackbar(
          'Modifications enregistrées',
          updated.nom,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        final nature = NatureDepenseModel(
          id: '',
          nom: nomCtrl.text.trim(),
          description: desc,
          boutiqueId: bId!,
          active: active.value,
        );
        await _repo.create(nature);
        Get.back();
        Get.snackbar(
          'Nature créée',
          nature.nom,
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
