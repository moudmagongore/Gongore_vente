import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/boutique_repository.dart';

class BoutiqueFormController extends GetxController {
  final BoutiqueRepository _repo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();

  final RxBool active = true.obs;
  final RxBool isSaving = false.obs;

  /// null = création, sinon édition de cette boutique
  final Rxn<BoutiqueModel> editing = Rxn<BoutiqueModel>();

  bool get isEdit => editing.value != null;
  String get title => isEdit ? 'Modifier la boutique' : 'Nouvelle boutique';

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is BoutiqueModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      adresseCtrl.text = arg.adresse ?? '';
      telephoneCtrl.text = arg.telephone ?? '';
      active.value = arg.active;
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
    super.onClose();
  }

  String? validateNom(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Nom requis';
    if (value.length < 2) return 'Au moins 2 caractères';
    return null;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isSaving.value = true;
    try {
      if (isEdit) {
        final updated = editing.value!.copyWith(
          nom: nomCtrl.text.trim(),
          adresse: adresseCtrl.text.trim().isEmpty
              ? null
              : adresseCtrl.text.trim(),
          telephone: telephoneCtrl.text.trim().isEmpty
              ? null
              : telephoneCtrl.text.trim(),
          active: active.value,
        );
        await _repo.update(updated);
        Get.back();
        Get.snackbar(
          'Modifications enregistrées',
          updated.nom,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        final newBoutique = BoutiqueModel(
          id: '', // généré par Firestore
          nom: nomCtrl.text.trim(),
          adresse: adresseCtrl.text.trim().isEmpty
              ? null
              : adresseCtrl.text.trim(),
          telephone: telephoneCtrl.text.trim().isEmpty
              ? null
              : telephoneCtrl.text.trim(),
          // devise par défaut 'GNF' (cf. BoutiqueModel)
          active: active.value,
        );
        await _repo.create(newBoutique);
        Get.back();
        Get.snackbar(
          'Boutique créée',
          newBoutique.nom,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Enregistrement impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isSaving.value = false;
    }
  }
}
