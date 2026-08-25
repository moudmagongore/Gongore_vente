import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

/// Service global pour l'authentification biométrique (Face ID / Touch ID
/// sur iOS, empreinte / Face Unlock sur Android).
///
/// Stocke les identifiants email/mot de passe de manière chiffrée via
/// `flutter_secure_storage` (Keychain iOS, EncryptedSharedPreferences
/// Android) et les utilise pour reconnecter automatiquement l'utilisateur
/// après une vérification biométrique réussie.
///
/// Injecté en `permanent: true` dans `main.dart`.
class BiometricService extends GetxService {
  static BiometricService get to => Get.find();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _kEnabledKey = 'biometric_enabled';
  static const _kEmailKey = 'biometric_email';
  static const _kPasswordKey = 'biometric_password';

  /// Vrai si le device dispose de matériel biométrique configuré
  /// (Face ID configuré, empreinte enregistrée, etc.).
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Libellé court adapté au matériel détecté ("Face ID", "Touch ID",
  /// "empreinte", "biométrie").
  Future<String> typeLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (Platform.isIOS) {
        if (types.contains(BiometricType.face)) return 'Face ID';
        if (types.contains(BiometricType.fingerprint)) return 'Touch ID';
      } else {
        if (types.contains(BiometricType.fingerprint)) return 'empreinte';
        if (types.contains(BiometricType.face)) return 'reconnaissance faciale';
      }
    } catch (_) {}
    return 'biométrie';
  }

  /// Lance la prompt biométrique. Retourne `true` si l'utilisateur a été
  /// authentifié avec succès, `false` sinon (annulation, échec, indisponible).
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Persistance chiffrée des identifiants
  // ---------------------------------------------------------------------------

  Future<bool> isEnabled() async {
    final v = await _storage.read(key: _kEnabledKey);
    return v == '1';
  }

  Future<void> enable({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kEnabledKey, value: '1');
    await _storage.write(key: _kEmailKey, value: email);
    await _storage.write(key: _kPasswordKey, value: password);
  }

  Future<void> disable() async {
    await _storage.delete(key: _kEnabledKey);
    await _storage.delete(key: _kEmailKey);
    await _storage.delete(key: _kPasswordKey);
  }

  Future<({String email, String password})?> getCredentials() async {
    final email = await _storage.read(key: _kEmailKey);
    final password = await _storage.read(key: _kPasswordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }
}
