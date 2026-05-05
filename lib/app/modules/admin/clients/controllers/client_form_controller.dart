import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/client_repository.dart';

class ClientFormController extends GetxController {
  final ClientRepository _repo = ClientRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final soldeCtrl = TextEditingController();

  final RxnString boutiqueId = RxnString();
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;

  final RxBool isSaving = false.obs;
  final Rxn<ClientModel> editing = Rxn<ClientModel>();

  bool get isEdit => editing.value != null;
  String get title => isEdit ? 'Modifier le client' : 'Nouveau client';
  bool get canPickBoutique => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(
      scope: UserController.to.scopeBoutiqueId,
      actives: true,
    ));

    final arg = Get.arguments;
    if (arg is ClientModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      telephoneCtrl.text = arg.telephone ?? '';
      emailCtrl.text = arg.email ?? '';
      adresseCtrl.text = arg.adresse ?? '';
      noteCtrl.text = arg.note ?? '';
      soldeCtrl.text = arg.solde == 0 ? '' : arg.solde.toStringAsFixed(0);
      boutiqueId.value = arg.boutiqueId;
    } else if (!canPickBoutique) {
      // Admin de boutique : pré-remplir sa boutique
      boutiqueId.value = UserController.to.boutiqueId;
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    telephoneCtrl.dispose();
    emailCtrl.dispose();
    adresseCtrl.dispose();
    noteCtrl.dispose();
    soldeCtrl.dispose();
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

  double _parseSolde() {
    final raw = soldeCtrl.text.replaceAll(',', '.').trim();
    if (raw.isEmpty) return 0;
    return double.tryParse(raw) ?? 0;
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
      final solde = _parseSolde();
      String? optional(TextEditingController c) {
        final v = c.text.trim();
        return v.isEmpty ? null : v;
      }

      if (isEdit) {
        final updated = editing.value!.copyWith(
          nom: nomCtrl.text.trim(),
          telephone: optional(telephoneCtrl),
          email: optional(emailCtrl),
          adresse: optional(adresseCtrl),
          note: optional(noteCtrl),
          solde: solde,
        );
        await _repo.update(updated);
        Get.back();
        Get.snackbar(
          'Modifications enregistrées',
          updated.nom,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        final newClient = ClientModel(
          id: '',
          nom: nomCtrl.text.trim(),
          telephone: optional(telephoneCtrl),
          email: optional(emailCtrl),
          adresse: optional(adresseCtrl),
          note: optional(noteCtrl),
          boutiqueId: bId!,
          solde: solde,
        );
        await _repo.create(newClient);
        Get.back();
        Get.snackbar(
          'Client créé',
          newClient.nom,
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
