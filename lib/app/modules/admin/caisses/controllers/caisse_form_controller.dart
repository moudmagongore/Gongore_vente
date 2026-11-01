import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/caisse_repository.dart';
import '../../../../data/repositories/user_repository.dart';

/// Création et paramétrage d'une caisse. Réservé à l'admin et au
/// super-admin (garde de route `AdminGuard`).
class CaisseFormController extends GetxController {
  final CaisseRepository _repo = CaisseRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();

  final formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController();
  final soldeDepartCtrl = TextEditingController();
  final ordreCtrl = TextEditingController(text: '0');

  final RxnString boutiqueId = RxnString();
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> _users = <UserModel>[].obs;

  final RxBool active = true.obs;
  final RxBool autoriseNegatif = false.obs;

  /// Case « Accessible aux gestionnaires » (RG-2).
  final RxBool accessibleGestionnaires = false.obs;

  /// uid cochés parmi les gestionnaires proposés.
  final RxList<String> gestionnaireIds = <String>[].obs;

  final RxBool isSaving = false.obs;
  final Rxn<CaisseModel> editing = Rxn<CaisseModel>();

  /// uid présents dans la caisse mais absents des options proposées :
  /// comptes désactivés ou retirés de la boutique. On les conserve à
  /// l'enregistrement plutôt que de les effacer en silence — leur retrait
  /// doit rester une action volontaire de l'admin. Ils n'ont de toute
  /// façon plus accès à rien tant que leur compte est inactif.
  final List<String> _idsConserves = [];

  bool get isEdit => editing.value != null;
  String get title => isEdit ? 'Modifier la caisse' : 'Nouvelle caisse';
  bool get canPickBoutique => UserController.to.isSuperAdmin;

  /// Gestionnaires proposables : comptes actifs de la boutique ayant le
  /// rôle gestionnaire. Les admins qui cumulent le rôle n'y figurent pas,
  /// ils voient déjà toutes les caisses (RG-2).
  List<UserModel> get gestionnairesDisponibles {
    final bid = boutiqueId.value;
    if (bid == null || bid.isEmpty) return const [];
    return _users
        .where((u) =>
            u.role == UserRole.vendeur && u.active && u.boutiqueId == bid)
        .toList();
  }

  bool get aucunGestionnaire => gestionnairesDisponibles.isEmpty;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;
    boutiques.bindStream(_boutiqueRepo.watchScoped(
      scope: scope,
      actives: true,
    ));
    _users.bindStream(_userRepo.watchScoped(scope: scope));

    final arg = Get.arguments;
    if (arg is CaisseModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      ordreCtrl.text = arg.ordre.toString();
      boutiqueId.value = arg.boutiqueId;
      active.value = arg.active;
      autoriseNegatif.value = arg.autoriseNegatif;
      accessibleGestionnaires.value = arg.gestionnaireIds.isNotEmpty;
      gestionnaireIds.assignAll(arg.gestionnaireIds);
    } else if (!canPickBoutique) {
      boutiqueId.value = scope;
    }

    // Les gestionnaires arrivent par stream, donc après `onInit`. On
    // écoute chaque émission et non la première seulement : un stream
    // Firestore commence souvent par une liste vide (cache froid), et
    // caler la sélection automatique dessus ne ferait jamais rien.
    ever<List<UserModel>>(_users, (_) => _apresChargementUsers());
  }

  /// Idempotent : rejoué à chaque émission du stream des utilisateurs.
  void _apresChargementUsers() {
    final proposables = gestionnairesDisponibles.map((u) => u.id).toSet();
    for (final id in gestionnaireIds) {
      if (!proposables.contains(id) && !_idsConserves.contains(id)) {
        _idsConserves.add(id);
      }
    }
    gestionnaireIds.removeWhere((id) => !proposables.contains(id));
    _autoSelectionSiUnSeul();
  }

  /// Boutique avec un seul gestionnaire : cocher la case le sélectionne,
  /// l'admin n'a rien à choisir (RG-2).
  ///
  /// Au plus une fois : sans ce garde-fou, un admin qui décoche
  /// volontairement l'unique gestionnaire le verrait recoché à la
  /// prochaine émission du stream des utilisateurs.
  bool _autoSelectionFaite = false;

  void _autoSelectionSiUnSeul() {
    if (!accessibleGestionnaires.value || _autoSelectionFaite) return;
    final dispo = gestionnairesDisponibles;
    if (dispo.length == 1 && gestionnaireIds.isEmpty) {
      gestionnaireIds.assignAll([dispo.first.id]);
      _autoSelectionFaite = true;
    }
  }

  void setAccessibleGestionnaires(bool v) {
    accessibleGestionnaires.value = v;
    if (!v) {
      // Case décochée : la caisse n'est accessible à aucun gestionnaire.
      gestionnaireIds.clear();
      _idsConserves.clear();
      _autoSelectionFaite = false;
    } else {
      _autoSelectionSiUnSeul();
    }
  }

  void toggleGestionnaire(String uid) {
    if (gestionnaireIds.contains(uid)) {
      gestionnaireIds.remove(uid);
    } else {
      gestionnaireIds.add(uid);
    }
  }

  /// Le changement de boutique (super-admin) invalide la sélection : les
  /// gestionnaires ne sont pas les mêmes.
  void setBoutique(String? id) {
    if (boutiqueId.value == id) return;
    boutiqueId.value = id;
    gestionnaireIds.clear();
    _idsConserves.clear();
    _autoSelectionFaite = false;
    _autoSelectionSiUnSeul();
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    soldeDepartCtrl.dispose();
    ordreCtrl.dispose();
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

  /// Le solde de départ est facultatif (vide = 0) mais doit être un nombre.
  String? validateSoldeDepart(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final montant = double.tryParse(value);
    if (montant == null) return 'Montant invalide';
    if (montant < 0) return 'Le solde de départ ne peut pas être négatif';
    return null;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final bId = boutiqueId.value;
    if (validateBoutique(bId) != null) {
      _snackError('Boutique requise');
      return;
    }
    // RG-2 : cocher la case sans choisir personne n'a pas de sens.
    if (accessibleGestionnaires.value && gestionnaireIds.isEmpty) {
      _snackError(
        'Choisissez au moins un gestionnaire, ou décochez '
        '« Accessible aux gestionnaires ».',
      );
      return;
    }

    final ids = accessibleGestionnaires.value
        ? <String>{...gestionnaireIds, ..._idsConserves}.toList()
        : <String>[];
    final ordre = int.tryParse(ordreCtrl.text.trim()) ?? 0;

    isSaving.value = true;
    try {
      if (isEdit) {
        final updated = editing.value!.copyWith(
          nom: nomCtrl.text.trim(),
          active: active.value,
          gestionnaireIds: ids,
          autoriseNegatif: autoriseNegatif.value,
          ordre: ordre,
        );
        await _repo.updateParametres(updated);
        Get.back();
        Get.snackbar(
          'Modifications enregistrées',
          updated.nom,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        final soldeDepart =
            double.tryParse(soldeDepartCtrl.text.trim()) ?? 0;
        final user = UserController.to.user;
        final caisse = CaisseModel(
          id: '',
          nom: nomCtrl.text.trim(),
          boutiqueId: bId!,
          active: active.value,
          gestionnaireIds: ids,
          autoriseNegatif: autoriseNegatif.value,
          ordre: ordre,
        );
        await _repo.create(
          caisse,
          soldeDepart: soldeDepart,
          userId: user?.id ?? '',
          userNom: user?.nom ?? '',
        );
        Get.back();
        Get.snackbar(
          'Caisse créée',
          soldeDepart > 0
              ? '${caisse.nom} — solde de départ enregistré.'
              : caisse.nom,
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
