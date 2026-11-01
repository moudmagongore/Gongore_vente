import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/repositories/caisse_repository.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/repositories/boutique_repository.dart';

class BoutiqueFormController extends GetxController {
  final BoutiqueRepository _repo = BoutiqueRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();

  final RxBool active = true.obs;

  /// Module de caisse ouvert à cette boutique. Réservé au super-admin :
  /// le champ n'apparaît pas pour un admin, et les règles Firestore
  /// l'empêchent de le modifier même par une requête forgée.
  final RxBool caissesActivees = false.obs;

  bool get peutOuvrirCaisses => UserController.to.isSuperAdmin;
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
      caissesActivees.value = arg.caissesActivees;
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

  /// Fermer le module sur une boutique dont les caisses contiennent encore
  /// de l'argent mérite une confirmation : les soldes ne bougeront plus
  /// alors que la boutique continue d'encaisser, et ils seront donc faux à
  /// la réactivation.
  ///
  /// Rien n'est supprimé pour autant : caisses et mouvements sont
  /// conservés et réapparaissent intacts si le module est rouvert.
  Future<bool> _confirmerFermetureCaisses() async {
    final avant = editing.value;
    if (avant == null) return true;
    if (!(avant.caissesActivees && !caissesActivees.value)) return true;

    List<CaisseModel> avecSolde = const [];
    try {
      final caisses = await CaisseRepository().getActives(avant.id);
      avecSolde = caisses.where((c) => c.solde != 0).toList();
    } catch (_) {
      // Lecture impossible : on préfère demander confirmation que fermer
      // le module en aveugle.
      avecSolde = const [];
    }
    if (avecSolde.isEmpty) return true;

    final detail = avecSolde
        .map((c) => '• ${c.nom} : ${Fmt.money(c.solde, currency: 'GNF')}')
        .join('\n');
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Fermer le module de caisse ?'),
        content: Text(
          'Ces caisses contiennent encore de l\'argent :\n\n$detail\n\n'
          'Leurs soldes cesseront d\'être mis à jour alors que la boutique '
          'continuera d\'encaisser : ils seront faux si vous rouvrez le '
          'module plus tard.\n\n'
          'Rien n\'est supprimé : caisses et mouvements sont conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Get.back(result: true),
            child: const Text('Fermer quand même'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!await _confirmerFermetureCaisses()) return;

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
          caissesActivees: caissesActivees.value,
        );
        await _repo.update(updated);
        Get.back();
        Get.snackbar(
          'Modifications enregistrées',
          updated.nom,
          snackPosition: SnackPosition.TOP,
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
          caissesActivees: caissesActivees.value,
        );
        await _repo.create(newBoutique);
        Get.back();
        Get.snackbar(
          'Boutique créée',
          newBoutique.nom,
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Enregistrement impossible : $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      isSaving.value = false;
    }
  }
}
