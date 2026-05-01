import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/services/user_creation_service.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/user_repository.dart';

class UserFormController extends GetxController {
  final UserRepository _userRepo = UserRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserCreationService _creation = UserCreationService();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController(text: '+224 ');
  final passwordCtrl = TextEditingController();

  final Rx<UserRole> role = UserRole.vendeur.obs;
  final RxnString boutiqueId = RxnString();
  final RxBool active = true.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool sendResetEmail = true.obs;

  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxBool isSaving = false.obs;

  /// null = création, sinon édition
  final Rxn<UserModel> editing = Rxn<UserModel>();

  bool get isEdit => editing.value != null;
  String get title => isEdit ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur';

  /// Super-admin peut créer des admins. Admin de boutique : vendeurs uniquement.
  bool get canCreateAdmin => UserController.to.isSuperAdmin;

  /// Super-admin peut choisir n'importe quelle boutique. Admin : la sienne uniquement.
  bool get canPickBoutique => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    boutiques.bindStream(_boutiqueRepo.watchScoped(
      scope: UserController.to.scopeBoutiqueId,
      actives: true,
    ));

    final arg = Get.arguments;
    if (arg is UserModel) {
      editing.value = arg;
      nomCtrl.text = arg.nom;
      emailCtrl.text = arg.email;
      telephoneCtrl.text = arg.telephone ?? '+224 ';
      role.value = arg.role;
      boutiqueId.value = arg.boutiqueId;
      active.value = arg.active;
    } else if (!canCreateAdmin) {
      // Création par un admin de boutique : forcer rôle vendeur
      // et pré-remplir sa boutique.
      role.value = UserRole.vendeur;
      boutiqueId.value = UserController.to.boutiqueId;
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    emailCtrl.dispose();
    telephoneCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }

  String? validateNom(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Nom requis';
    if (value.length < 2) return 'Au moins 2 caractères';
    return null;
  }

  String? validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email requis';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) return 'Email invalide';
    return null;
  }

  String? validatePassword(String? v) {
    if (isEdit) return null; // pas modifié en édition
    if (v == null || v.isEmpty) return 'Mot de passe requis';
    if (v.length < 6) return 'Au moins 6 caractères';
    return null;
  }

  String? validateBoutique(String? v) {
    // Une boutique est requise pour TOUS les rôles non-super-admin
    // (admin de boutique + vendeur).
    if (role.value != UserRole.superAdmin && (v == null || v.isEmpty)) {
      return 'Sélectionnez une boutique';
    }
    return null;
  }

  void generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    final pwd = List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
    passwordCtrl.text = pwd;
    obscurePassword.value = false;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final boutiqueErr = validateBoutique(boutiqueId.value);
    if (boutiqueErr != null) {
      _snackError(boutiqueErr);
      return;
    }

    isSaving.value = true;
    try {
      if (isEdit) {
        await _saveEdit();
      } else {
        await _saveCreate();
      }
    } on FirebaseAuthException catch (e) {
      _snackError(_mapAuthError(e));
    } catch (e) {
      _snackError('Erreur : $e');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _saveCreate() async {
    final boutiqueIdToSave =
        role.value == UserRole.superAdmin ? null : boutiqueId.value;
    // ignore: avoid_print
    print('[USER CREATE] role=${role.value.name} '
        'boutiqueId.value=${boutiqueId.value} '
        'boutiqueIdToSave=$boutiqueIdToSave');
    await _creation.createUser(
      email: emailCtrl.text,
      password: passwordCtrl.text,
      nom: nomCtrl.text,
      telephone: telephoneCtrl.text,
      role: role.value,
      boutiqueId: boutiqueIdToSave,
      active: active.value,
    );

    if (sendResetEmail.value) {
      try {
        await _creation.sendPasswordResetEmail(emailCtrl.text);
      } catch (_) {
        // non bloquant
      }
    }

    Get.back();
    Get.snackbar(
      'Utilisateur créé',
      sendResetEmail.value
          ? 'Un email de définition de mot de passe a été envoyé.'
          : nomCtrl.text.trim(),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _saveEdit() async {
    final updated = editing.value!.copyWith(
      nom: nomCtrl.text.trim(),
      telephone: telephoneCtrl.text.trim().isEmpty
          ? null
          : telephoneCtrl.text.trim(),
      role: role.value,
      boutiqueId:
          role.value == UserRole.superAdmin ? null : boutiqueId.value,
      active: active.value,
    );
    await _userRepo.update(updated);

    Get.back();
    Get.snackbar(
      'Modifications enregistrées',
      updated.nom,
      snackPosition: SnackPosition.BOTTOM,
    );
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

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email';
      case 'invalid-email':
        return 'Email invalide';
      case 'weak-password':
        return 'Mot de passe trop faible (min. 6 caractères)';
      case 'network-request-failed':
        return 'Pas de connexion internet';
      default:
        return e.message ?? 'Erreur d\'authentification';
    }
  }
}
