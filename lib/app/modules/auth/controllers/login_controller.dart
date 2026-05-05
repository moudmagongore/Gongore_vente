import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/user_controller.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;

  /// Vrai si le device a du matériel biométrique configuré ET que
  /// l'utilisateur a activé la connexion biométrique précédemment.
  final RxBool biometricReady = false.obs;

  /// Libellé adapté au matériel ("Face ID", "empreinte", ...).
  final RxString biometricLabel = 'biométrie'.obs;

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
    _refreshBiometricState();
  }

  Future<void> _refreshBiometricState() async {
    final svc = BiometricService.to;
    final available = await svc.isAvailable();
    final enabled = await svc.isEnabled();
    biometricReady.value = available && enabled;
    if (available) {
      biometricLabel.value = await svc.typeLabel();
    }
  }

  @override
  void onReady() {
    super.onReady();
    // Auto-prompt biométrique au démarrage si l'utilisateur l'a activé.
    _maybeAutoBiometric();
  }

  Future<void> _maybeAutoBiometric() async {
    // Attend que le state biométrique soit chargé.
    await Future.delayed(const Duration(milliseconds: 300));
    if (biometricReady.value && !isLoading.value) {
      await signInWithBiometric();
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
    await _doSignIn(
      email: emailCtrl.text,
      password: passwordCtrl.text,
      askEnableBiometric: true,
    );
  }

  /// Connexion biométrique : déclenche la prompt système puis réutilise
  /// les identifiants stockés en chiffré pour signer in via Firebase.
  Future<void> signInWithBiometric() async {
    final svc = BiometricService.to;
    if (!await svc.isAvailable() || !await svc.isEnabled()) return;

    final label = await svc.typeLabel();
    final ok = await svc.authenticate(
      reason: 'Confirmez avec $label pour vous connecter.',
    );
    if (!ok) return;

    final creds = await svc.getCredentials();
    if (creds == null) {
      _snackError('Identifiants biométriques introuvables. Reconnectez-vous manuellement.');
      await svc.disable();
      biometricReady.value = false;
      return;
    }

    await _doSignIn(
      email: creds.email,
      password: creds.password,
      askEnableBiometric: false,
      disableBiometricOnWrongPassword: true,
    );
  }

  Future<void> _doSignIn({
    required String email,
    required String password,
    required bool askEnableBiometric,
    bool disableBiometricOnWrongPassword = false,
  }) async {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    UserController.to.errorMessage.value = null;
    isLoading.value = true;
    try {
      await AuthService.to.signInWithEmail(
        email: email,
        password: password,
      );

      final ok = await UserController.to.refreshFromAuth();
      if (!ok) {
        final msg = UserController.to.errorMessage.value ??
            'Connexion impossible.';
        _snackError(msg);
        return;
      }

      if (askEnableBiometric) {
        await _maybePromptEnableBiometric(email: email, password: password);
      }

      // Super-admin OU admin de boutique → /admin
      final route = UserController.to.isAnyAdmin
          ? AppRoutes.adminHome
          : AppRoutes.vendeurHome;
      Get.offAllNamed(route);
    } on FirebaseAuthException catch (e) {
      // Mot de passe stocké obsolète (changé via reset email) →
      // désactive la biométrie pour éviter une boucle d'échecs.
      if (disableBiometricOnWrongPassword &&
          (e.code == 'wrong-password' ||
              e.code == 'invalid-credential' ||
              e.code == 'user-not-found')) {
        await BiometricService.to.disable();
        biometricReady.value = false;
        _snackError('Vos identifiants ont changé. Reconnectez-vous manuellement.');
      } else {
        _snackError(_mapAuthError(e));
      }
    } catch (e) {
      _snackError('Erreur : $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _maybePromptEnableBiometric({
    required String email,
    required String password,
  }) async {
    final svc = BiometricService.to;
    if (!await svc.isAvailable()) return;
    if (await svc.isEnabled()) {
      // Refresh des identifiants stockés au cas où le mot de passe a changé.
      await svc.enable(email: email, password: password);
      return;
    }

    final label = await svc.typeLabel();
    final accept = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Activer $label ?'),
        content: Text(
            'Connectez-vous plus rapidement la prochaine fois en utilisant $label.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Activer'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    if (accept != true) return;

    final ok = await svc.authenticate(
      reason: 'Confirmez avec $label pour activer la connexion rapide.',
    );
    if (!ok) return;

    await svc.enable(email: email, password: password);
    biometricReady.value = true;
  }

  Future<void> sendPasswordReset() async {
    final email = emailCtrl.text.trim();
    if (validateEmail(email) != null) {
      _snackError('Veuillez renseigner une adresse e-mail valide dans le champ e-mail pour réinitialiser votre mot de passe.');
      return;
    }
    try {
      await AuthService.to.sendPasswordResetEmail(email);
      Get.snackbar(
        'Email envoyé',
        'Un lien de réinitialisation a été envoyé à $email',
        snackPosition: SnackPosition.TOP,
      );
    } on FirebaseAuthException catch (e) {
      _snackError(_mapAuthError(e));
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
