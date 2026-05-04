import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/user_controller.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Reset l'état d'erreur résiduel d'une session précédente (force-signOut
    // après désactivation boutique/user) pour éviter d'afficher un message
    // « toujours désactivé » alors que la situation a été corrigée.
    UserController.to.errorMessage.value = null;
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }

  void toggleObscure() => obscurePassword.toggle();

  String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email requis';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(v)) return 'Email invalide';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis';
    if (value.length < 6) return 'Au moins 6 caractères';
    return null;
  }

  Future<void> signIn() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    // Ferme un éventuel snackbar résiduel ("Votre boutique a été
    // désactivée...") pour qu'on ne le confonde pas avec la nouvelle
    // tentative de connexion.
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    UserController.to.errorMessage.value = null;
    isLoading.value = true;
    try {
      await AuthService.to.signInWithEmail(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );

      final ok = await UserController.to.refreshFromAuth();
      if (!ok) {
        final msg = UserController.to.errorMessage.value ??
            'Connexion impossible.';
        _snackError(msg);
        return;
      }

      // Super-admin OU admin de boutique → /admin
      final route = UserController.to.isAnyAdmin
          ? AppRoutes.adminHome
          : AppRoutes.vendeurHome;
      Get.offAllNamed(route);
    } on FirebaseAuthException catch (e) {
      _snackError(_mapAuthError(e));
    } catch (e) {
      _snackError('Erreur : $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordReset() async {
    final email = emailCtrl.text.trim();
    if (validateEmail(email) != null) {
      _snackError('Saisissez un email valide pour réinitialiser');
      return;
    }
    try {
      await AuthService.to.sendPasswordResetEmail(email);
      Get.snackbar(
        'Email envoyé',
        'Un lien de réinitialisation a été envoyé à $email',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (e) {
      _snackError(_mapAuthError(e));
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

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email invalide';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Pas de connexion internet';
      default:
        return e.message ?? 'Erreur d\'authentification';
    }
  }
}
