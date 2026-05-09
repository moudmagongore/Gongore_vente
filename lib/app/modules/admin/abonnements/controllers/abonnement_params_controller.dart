import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/abonnement_model.dart';
import '../../../../data/models/abonnement_params_model.dart';
import '../../../../data/repositories/abonnement_params_repository.dart';

class AbonnementParamsController extends GetxController {
  final AbonnementParamsRepository _repo = AbonnementParamsRepository();

  /// Devises pour lesquelles on configure des tarifs. On commence par GNF
  /// (la seule actuellement en usage côté boutiques) ; ajouter ici si
  /// d'autres devises arrivent.
  static const devises = ['GNF'];

  final formKey = GlobalKey<FormState>();
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  /// Map controllers : `${devise}_${periode.name}` → TextEditingController
  /// pour le tarif. Initialisé une fois et ré-utilisé.
  final Map<String, TextEditingController> tarifCtrls = {};
  final TextEditingController graceCtrl = TextEditingController(text: '3');
  final TextEditingController warningCtrl = TextEditingController(text: '7');

  @override
  void onInit() {
    super.onInit();
    for (final devise in devises) {
      for (final p in AbonnementPeriode.values) {
        tarifCtrls['${devise}_${p.name}'] = TextEditingController();
      }
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final params = await _repo.get();
      for (final entry in params.tarifs.entries) {
        final ctrl = tarifCtrls[entry.key];
        if (ctrl != null) {
          ctrl.text =
              entry.value > 0 ? entry.value.toStringAsFixed(0) : '';
        }
      }
      graceCtrl.text = params.graceDays.toString();
      warningCtrl.text = params.warningThresholdDays.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in tarifCtrls.values) {
      c.dispose();
    }
    graceCtrl.dispose();
    warningCtrl.dispose();
    super.onClose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    isSaving.value = true;
    try {
      final tarifs = <String, double>{};
      for (final e in tarifCtrls.entries) {
        final v = double.tryParse(e.value.text.trim().replaceAll(',', '.'));
        if (v != null && v > 0) {
          tarifs[e.key] = v;
        }
      }
      final grace = int.tryParse(graceCtrl.text.trim()) ?? 0;
      final warning = int.tryParse(warningCtrl.text.trim()) ?? 7;
      await _repo.save(AbonnementParamsModel(
        tarifs: tarifs,
        graceDays: grace < 0 ? 0 : grace,
        warningThresholdDays: warning < 0 ? 0 : warning,
      ));
      Get.back();
      Get.snackbar(
        'Paramètres enregistrés',
        '${tarifs.length} tarif(s) configuré(s)',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        '$e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isSaving.value = false;
    }
  }
}
